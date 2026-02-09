# Swish Dev Environment Platform — Architecture

This document covers production designs for capabilities beyond the current Minikube implementation.

## 1. Cluster Autoscaling

### Approach

Use **Karpenter** (preferred on EKS) or **Cluster Autoscaler** to dynamically provision nodes as dev environments are created.

### Node Groups

| Node Group | Instance Types | Purpose | Taints |
|------------|---------------|---------|--------|
| `general-dev` | m5.large–m5.2xlarge | Default dev environments | None (default pool) |
| `high-memory` | r5.4xlarge–r5.16xlarge | Data workloads requiring 100–250GB RAM | `swish.io/workload=high-memory:NoSchedule` |
| `gpu` | p3.2xlarge, g4dn.xlarge | ML/deep learning environments | `swish.io/workload=gpu:NoSchedule` |

### Team/Project Segregation

- Nodes are labeled with `swish.io/team` and `swish.io/project` at scheduling time via `nodeAffinity` rules in the Helm chart
- ResourceQuotas per namespace enforce per-team resource caps
- Karpenter provisioners can be scoped per team to enforce instance type and count limits

### Scaling Configuration

```yaml
# Karpenter Provisioner example
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: general-dev
spec:
  requirements:
    - key: node.kubernetes.io/instance-type
      operator: In
      values: [m5.large, m5.xlarge, m5.2xlarge]
    - key: karpenter.sh/capacity-type
      operator: In
      values: [on-demand, spot]
  limits:
    resources:
      cpu: "100"
      memory: 400Gi
  ttlSecondsAfterEmpty: 300
```

Spot instances are suitable for general-dev environments (dev work is interruptible). High-memory and GPU pools use on-demand for stability.

## 2. SSH/SFTP Access

### Architecture

Each dev environment optionally runs an SSH sidecar container (enabled via `ssh.enabled=true` in the Helm chart). The sidecar shares a workspace volume with the main dev container.

### DNS Automation

- **ExternalDNS** watches for Services with annotation `external-dns.alpha.kubernetes.io/hostname`
- When a dev environment is created with SSH enabled, the Service is annotated:
  ```
  external-dns.alpha.kubernetes.io/hostname: <release-name>.dev.swish.io
  ```
- ExternalDNS creates a DNS A or CNAME record in Route 53 pointing to the Service's LoadBalancer
- Record TTL: 60 seconds for fast propagation
- On `helm uninstall`, the Service is deleted and ExternalDNS cleans up the DNS record

### Connection Flow

```
User laptop
  └─ ssh user@my-env.dev.swish.io
       └─ Route 53 → LoadBalancer → Service (port 22) → SSH sidecar (port 2222)
            └─ shared /workspace volume ← main dev container
```

### Security

- SSH keys injected via Kubernetes Secret mounted into the sidecar
- Password authentication disabled in production (enabled for dev/demo only)
- NetworkPolicies restrict SSH ingress to corporate IP ranges
- Audit logging via SSH sidecar logs shipped to centralized logging

## 3. High-Memory Workloads (100–250GB)

### Dedicated Node Pool

Workloads requiring 100–250GB of in-memory data run on a dedicated `high-memory` node pool:
- **Instance types**: r5.8xlarge (256GB), r5.16xlarge (512GB)
- **Taint**: `swish.io/workload=high-memory:NoSchedule` — only pods with matching tolerations are scheduled
- **The Helm chart** adds tolerations when `resources.requests.memory` exceeds a configurable threshold (e.g., 64Gi)

### Memory-Mapped Files

For datasets that don't need to be entirely in RAM simultaneously:
- Use a large EBS volume (io2 or gp3) mounted into the pod
- Application uses `mmap()` to access the file — the kernel pages data in/out as needed
- Reduces actual memory footprint while supporting datasets larger than physical RAM

### Monitoring and Protection

- **DevEnvHighMemory** alert fires at 85% of memory limit (5-minute window) to warn before OOMKill
- **PodDisruptionBudgets (PDBs)** prevent voluntary eviction of high-memory pods during node maintenance:
  ```yaml
  apiVersion: policy/v1
  kind: PodDisruptionBudget
  metadata:
    name: high-memory-pdb
  spec:
    minAvailable: 1
    selector:
      matchLabels:
        swish.io/workload: high-memory
  ```
- Graceful shutdown hooks allow the application to checkpoint state before termination

### Resource Guarantees

Set `requests == limits` for memory on high-memory pods to get **Guaranteed QoS class**, preventing the kubelet from evicting them under memory pressure.

## 4. Usage Tracking and Chargeback

### Metrics Collection

All dev environment pods carry `swish.io/team` and `swish.io/project` labels. Prometheus queries aggregate resource usage by these labels:

```promql
# Total CPU usage by team (cores)
sum by (label_swish_io_team) (
  rate(container_cpu_usage_seconds_total{container="dev"}[1h])
)

# Total memory usage by project (GB)
sum by (label_swish_io_project) (
  container_memory_working_set_bytes{container="dev"}
) / 1e9
```

### Cost Attribution

- **Kubecost** (or OpenCost) installed in the cluster to map resource usage to cloud spend
- Kubecost labels-based allocation assigns costs to teams and projects using the same `swish.io/*` labels
- Weekly reports emailed to team leads showing:
  - Total compute hours consumed
  - Idle environment hours (wasted spend)
  - Cost comparison: actual usage vs. requested resources (over-provisioning cost)

### Idle Environment Policy

| Idle Duration | Action |
|---------------|--------|
| 30 minutes | Alert fired (DevEnvIdle) |
| 2 hours | Notification sent to environment owner |
| 8 hours | Environment auto-scaled to minimum resources via VPA |
| 24 hours | Environment auto-terminated (with 1-hour warning) |

Implementation: a CronJob runs a script that queries Prometheus for idle pods and applies the policy via `helm upgrade` (downscale) or `helm uninstall` (terminate).

## 5. Triggering Dev Environments via GitHub Actions

A GitHub Actions workflow lets users launch, update, or tear down dev environments directly from the repo — either through `workflow_dispatch` (manual trigger in the GitHub UI) or automatically on branch events.

### Self-Hosted Runner Requirement

The workflow uses a **self-hosted runner** inside the cluster (or with kubeconfig access) so that `helm` and `kubectl` commands target the correct cluster without exposing credentials externally. Alternatives:
- Store a kubeconfig as a GitHub Actions secret and configure it in the workflow (works with cloud-hosted runners)
- Use a cloud provider CLI (e.g., `aws eks update-kubeconfig`) to authenticate at runtime

### Workflow: Manual Launch (`workflow_dispatch`)

```yaml
# .github/workflows/dev-env.yaml
name: Dev Environment

on:
  workflow_dispatch:
    inputs:
      action:
        description: "Action to perform"
        required: true
        type: choice
        options:
          - launch
          - teardown
      env_name:
        description: "Environment name (used as Helm release name)"
        required: true
        type: string
      image:
        description: "Base image"
        required: true
        type: choice
        options:
          - cthomaspdx1/swish-python3
          - cthomaspdx1/swish-python2
          - cthomaspdx1/swish-r
      team:
        description: "Team label"
        required: false
        type: string
      memory:
        description: "Memory request (e.g. 512Mi, 2Gi)"
        required: false
        default: "256Mi"
        type: string
      cpu:
        description: "CPU request (e.g. 250m, 1)"
        required: false
        default: "250m"
        type: string
      pip_packages:
        description: "Comma-separated pip packages (e.g. flask,requests)"
        required: false
        type: string
      ssh_enabled:
        description: "Enable SSH access"
        required: false
        type: boolean
        default: false

jobs:
  manage-env:
    runs-on: self-hosted
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Launch environment
        if: inputs.action == 'launch'
        run: |
          HELM_ARGS="--set image.repository=${{ inputs.image }}"
          HELM_ARGS="$HELM_ARGS --set resources.requests.memory=${{ inputs.memory }}"
          HELM_ARGS="$HELM_ARGS --set resources.requests.cpu=${{ inputs.cpu }}"
          HELM_ARGS="$HELM_ARGS --set ssh.enabled=${{ inputs.ssh_enabled }}"

          if [ -n "${{ inputs.team }}" ]; then
            HELM_ARGS="$HELM_ARGS --set team=${{ inputs.team }}"
          fi

          if [ -n "${{ inputs.pip_packages }}" ]; then
            # Convert comma-separated to Helm list format
            PKGS=$(echo "${{ inputs.pip_packages }}" | tr ',' '\n' | sed 's/.*/{&}/' | tr '\n' ',' | sed 's/,$//')
            HELM_ARGS="$HELM_ARGS --set customPackages.pip={${{ inputs.pip_packages }}}"
          fi

          helm upgrade --install "${{ inputs.env_name }}" ./helm/dev-env \
            --namespace swish --create-namespace \
            $HELM_ARGS

          echo "### Environment launched" >> $GITHUB_STEP_SUMMARY
          echo "- **Name:** ${{ inputs.env_name }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Image:** ${{ inputs.image }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Resources:** ${{ inputs.cpu }} CPU / ${{ inputs.memory }} memory" >> $GITHUB_STEP_SUMMARY

      - name: Teardown environment
        if: inputs.action == 'teardown'
        run: |
          helm uninstall "${{ inputs.env_name }}" --namespace swish
          echo "### Environment torn down: ${{ inputs.env_name }}" >> $GITHUB_STEP_SUMMARY

      - name: Show status
        if: inputs.action == 'launch'
        run: |
          kubectl get pods -n swish -l app.kubernetes.io/instance=${{ inputs.env_name }} --watch=false
```

### How to Use

1. Go to the repo on GitHub → **Actions** tab → **Dev Environment** workflow
2. Click **Run workflow**
3. Fill in the form: choose launch/teardown, set image, team, resources, packages
4. The workflow runs on the self-hosted runner and applies the Helm chart to the cluster

### Workflow: Branch-Based Environments (Optional)

For preview-style environments that spin up automatically when a branch is created:

```yaml
# .github/workflows/branch-env.yaml
name: Branch Dev Environment

on:
  create:
  delete:

jobs:
  manage-branch-env:
    if: github.event.ref_type == 'branch' && github.event.ref != 'main'
    runs-on: self-hosted
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Sanitize branch name
        id: branch
        run: |
          # Convert branch name to valid Helm release / K8s name
          NAME=$(echo "${{ github.event.ref }}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | head -c 53)
          echo "name=$NAME" >> $GITHUB_OUTPUT

      - name: Launch on branch create
        if: github.event_name == 'create'
        run: |
          helm upgrade --install "dev-${{ steps.branch.outputs.name }}" ./helm/dev-env \
            --namespace swish --create-namespace \
            --set image.repository=cthomaspdx1/swish-python3 \
            --set team=${{ github.actor }}

      - name: Teardown on branch delete
        if: github.event_name == 'delete'
        run: |
          helm uninstall "dev-${{ steps.branch.outputs.name }}" --namespace swish || true
```

### Integration with Existing Argo CI

The existing Argo Workflows CI pipeline (`argo/workflows/ci.yaml`) handles image builds and deploys. The GitHub Actions workflow above is complementary — it manages per-user dev environments while Argo handles the shared CI/CD pipeline. They can coexist:

| Concern | Tool |
|---------|------|
| Image build, CVE scan, deploy to shared envs | Argo Workflows + Argo Events |
| Per-user dev environment lifecycle | GitHub Actions + Helm chart |
