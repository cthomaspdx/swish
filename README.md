# Swish

DevSecOps platform for dynamically launching custom development environments on Kubernetes.

## Repository Structure

```
argo/
  argocd/              # ArgoCD Application manifests (per-image + spark)
  events/              # Argo Events webhook eventsource + sensor
  workflows/           # Argo Workflows CI pipeline + RBAC
docker/                # Dockerfiles and requirements files
docs/                  # CVE remediation reports
helm/
  dev-env/             # Helm chart for per-user dev environments
k8s/
  python2/             # Python 2 deployment + service
  python3/             # Python 3 deployment + service
  r/                   # R deployment + service
monitoring/            # Prometheus alert rules + Grafana dashboard
spark/                 # Spark Operator RBAC, sample data, PySpark ETL job
```

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

### Spark Operator

Runs Apache Spark workloads (PySpark, Scala, R) natively on Kubernetes.

- **Chart version used:** latest (kubeflow/spark-operator)
- **Install:** https://github.com/kubeflow/spark-operator

```bash
helm repo add spark-operator https://kubeflow.github.io/spark-operator
helm repo update

helm install spark-operator spark-operator/spark-operator \
  --namespace spark-operator --create-namespace \
  --set spark.jobNamespaces="{swish}" \
  --wait
```

## Spark: PySpark ETL Job

A sample PySpark ETL job is included under `spark/` to demonstrate distributed data processing on the platform. The job reads an NFL player stats CSV dataset, computes per-player total yards, and produces team and position aggregates.

### Manifests

| File | Purpose |
|------|---------|
| `spark/rbac.yaml` | ServiceAccount, Role, and RoleBinding for the Spark driver |
| `spark/sample-data-cm.yaml` | ConfigMap with sample NFL stats CSV (~30 rows) |
| `spark/pyspark-etl.yaml` | PySpark script ConfigMap + SparkApplication CR |
| `argo/argocd/swish-spark.yaml` | ArgoCD Application — auto-syncs the `spark/` directory |

### Running the Job

ArgoCD will auto-sync the manifests. To run manually:

```bash
kubectl apply -f spark/rbac.yaml
kubectl apply -f spark/sample-data-cm.yaml
kubectl apply -f spark/pyspark-etl.yaml

# Watch job status
kubectl get sparkapplication -n swish

# View results
kubectl logs pyspark-etl-driver -n swish | grep -A 20 "^==="

# Clean up
kubectl delete sparkapplication pyspark-etl -n swish
```

### Sample Output

The driver logs show three result tables:

**Top 10 Players by Total Yards**

```
+---------------+----+--------+-----------+----------+
|player         |team|position|total_yards|touchdowns|
+---------------+----+--------+-----------+----------+
|Patrick Mahomes|KC  |QB      |5608       |45        |
|Josh Allen     |BUF |QB      |5374       |42        |
|Joe Burrow     |CIN |QB      |4757       |35        |
|Lamar Jackson  |BAL |QB      |4621       |37        |
|Jalen Hurts    |PHI |QB      |4505       |33        |
|Derrick Henry  |BAL |RB      |1995       |16        |
|Bijan Robinson |ATL |RB      |1980       |13        |
|Saquon Barkley |PHI |RB      |1960       |14        |
|Jahmyr Gibbs   |DET |RB      |1800       |12        |
|Josh Jacobs    |GB  |RB      |1760       |12        |
+---------------+----+--------+-----------+----------+
```

**Team Aggregates**

```
+----+---------+-----------+------------+
|team|total_tds|total_yards|player_count|
+----+---------+-----------+------------+
|KC  |60       |7890       |3           |
|BAL |59       |7376       |3           |
|PHI |57       |7837       |3           |
|CIN |49       |6332       |2           |
|BUF |42       |5374       |1           |
|DET |30       |4236       |3           |
|MIA |24       |3352       |2           |
|NYJ |18       |2875       |2           |
|MIN |16       |2268       |2           |
|ATL |13       |1980       |1           |
|GB  |12       |1760       |1           |
|DAL |12       |1648       |1           |
|IND |11       |1600       |1           |
|TB  |9        |1268       |1           |
|LAR |9        |1400       |1           |
|LV  |9        |1305       |1           |
|SF  |7        |905        |1           |
|NO  |7        |1110       |1           |
+----+---------+-----------+------------+
```

**Position Averages**

```
+--------+-------+---------------+------------+
|position|avg_tds|avg_total_yards|player_count|
+--------+-------+---------------+------------+
|QB      |38.4   |4973.0         |5           |
|RB      |11.8   |1725.0         |9           |
|WR      |10.2   |1422.1         |11          |
|TE      |6.8    |896.6          |5           |
+--------+-------+---------------+------------+
```

## Deploying Swish

After all prerequisites are installed:

```bash
# Create Docker Hub credentials secret (needed for CI to push images)
# Edit argo/workflows/dockerhub-credentials.yaml with your Docker Hub username and PAT, then:
kubectl apply -f argo/workflows/dockerhub-credentials.yaml

# Create git credentials secret (needed for CI to push CVE reports back to repo)
# Edit argo/workflows/gitcreds.yaml with your GitHub username and PAT, then:
kubectl apply -f argo/workflows/gitcreds.yaml

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
