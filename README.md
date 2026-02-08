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
