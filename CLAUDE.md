# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Swish is a DevSecOps project implementing a Kubernetes-based platform that allows employees to dynamically launch custom development environments. The project has two parts:

**Part 1 — General DevSecOps tasks:**
- Multi-language Docker image (Python 2, Python 3, R) with requirements, pushed to Docker Hub
- Build time optimization
- CVE scanning and remediation of the container image
- Kubernetes deployment and service exposure
- CI/CD automation (GitHub Actions)
- Monitoring strategy

**Part 2 — Dev Environment Platform:**
- UI/workflow for users to select base image, packages, and resource requests (mem/CPU/GPU)
- Per-environment monitoring: resource accuracy, idle/underutilized alerts, auto-downscaling, usage tracking
- Cluster autoscaling with node groups/taints/tags for team/project segregation
- SSH/SFTP access with automated DNS handling
- Support for workloads requiring 100-250GB in-memory data

## Repository Structure

This is a greenfield repo. Expected layout as implementation progresses:

```
docker/              # Dockerfiles and requirements files
k8s/                 # Kubernetes manifests (deployments, services, HPA, VPA)
.github/workflows/   # CI/CD pipelines
monitoring/          # Prometheus/Grafana configs, alerting rules
docs/                # CVE reports, architecture decisions, build time analysis
```

## Key Commands (to be established)

```bash
# Docker
docker build -t swish-dev .
docker push <dockerhub-user>/swish-dev

# CVE scanning
trivy image <dockerhub-user>/swish-dev

# Kubernetes (assumes kubectl configured)
kubectl apply -f k8s/
kubectl get pods -n swish

# CI/CD runs via GitHub Actions on push to main
```

## Architecture Notes

- The Docker image must support Python 2, Python 3, and R in a single image — use multi-stage builds to minimize size and build time
- Kubernetes deployments need a long-running command (e.g., `tail -f /dev/null` or a supervisor process) to keep pods alive
- The platform portion requires dynamic pod creation per user request — consider an operator pattern or a simple API server that templates and applies manifests
- Node affinity, taints, and tolerations are used to segregate workloads across instance groups
- High-memory workloads (100-250GB) need dedicated node pools with appropriate instance types
