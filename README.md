# Swish

DevSecOps platform for dynamically launching custom development environments on Kubernetes.

## Cluster Prerequisites

The following components must be installed in the Minikube cluster before deploying Swish.

### Minikube

Local Kubernetes cluster.

- **Version used:** v1.37.0
- **Install:** https://minikube.sigs.k8s.io/docs/start/

```bash
minikube start --memory 8192 --cpus 4
```

### Argo Workflows

CI pipeline orchestration (build, scan, deploy).

- **Version used:** v4.0.0
- **Install:** https://argo-workflows.readthedocs.io/en/latest/quick-start/

```bash
kubectl create namespace argo
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v4.0.0/quick-start-minimal.yaml
```

### ArgoCD

GitOps continuous delivery — syncs Kubernetes manifests from the repo.

- **Version used:** v3.3.0
- **Install:** https://argo-cd.readthedocs.io/en/stable/getting_started/

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.3.0/manifests/install.yaml
```

### Argo Events

Event-driven webhook that triggers ArgoCD sync after CI completes.

- **Version used:** v1.9.6
- **Install:** https://argoproj.github.io/argo-events/installation/

```bash
kubectl create namespace argo-events
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/examples/eventbus/native.yaml
```

### Prometheus & Grafana (kube-prometheus-stack)

Cluster monitoring, alerting rules, and dashboards for dev environments.

- **Chart version used:** 81.5.0
- **Install:** https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=swish \
  --set grafana.sidecar.dashboards.enabled=true \
  --set grafana.sidecar.dashboards.searchNamespace=ALL \
  --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --wait
```

Apply Swish alert rules and Grafana dashboard:

```bash
kubectl apply -f monitoring/prometheus-rules.yaml -n monitoring
kubectl apply -f monitoring/grafana-dashboard-cm.yaml -n monitoring
```

Access the UIs via port-forward:

```bash
# Grafana (admin / swish)
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80

# Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090
```

## Deploying Swish

After all prerequisites are installed:

```bash
# Apply Argo Events manifests (webhook + sensor + RBAC)
kubectl apply -f argo/events/

# Apply CI workflow RBAC
kubectl apply -f argo/workflows/argo-deployer-rbac.yaml

# Submit a CI build
argo submit argo/workflows/ci.yaml -p target=all
```

## Launching a Dev Environment

Use the Helm chart to spin up a per-user dev environment:

```bash
# Launch a Python 3 environment with custom packages
helm install my-env ./helm/dev-env \
  --namespace swish \
  --set image.repository=cthomaspdx1/swish-python3 \
  --set "customPackages.pip={flask,requests}" \
  --set resources.requests.memory=1Gi \
  --set team=data-science

# Check pod status
kubectl get pods -n swish -l app.kubernetes.io/instance=my-env

# Tear down
helm uninstall my-env -n swish
```
