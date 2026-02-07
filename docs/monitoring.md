# Monitoring Strategy

## Recommended Stack

### Prometheus
- Cluster-level metrics collection via `kube-state-metrics` and `node-exporter`
- Scrapes pod resource usage (CPU, memory, network) at regular intervals
- Stores time-series data for alerting and dashboarding

### Grafana
- Visualization layer connected to Prometheus as a data source
- Pre-built dashboards for Kubernetes cluster overview, pod-level metrics, and node health

### Deployment
```bash
# Install via Helm (kube-prometheus-stack bundles Prometheus, Grafana, and alerting)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

## Key Metrics to Collect

### Pod-Level
| Metric | PromQL Example | Purpose |
|--------|---------------|---------|
| CPU usage | `rate(container_cpu_usage_seconds_total[5m])` | Detect CPU-bound workloads |
| Memory usage | `container_memory_working_set_bytes` | Detect memory pressure / OOM risk |
| Container restarts | `kube_pod_container_status_restarts_total` | Detect crash loops |
| Pod phase | `kube_pod_status_phase` | Track pod lifecycle |

### Node-Level
| Metric | PromQL Example | Purpose |
|--------|---------------|---------|
| Node CPU | `node_cpu_seconds_total` | Cluster capacity planning |
| Node memory | `node_memory_MemAvailable_bytes` | Identify memory-constrained nodes |
| Disk usage | `node_filesystem_avail_bytes` | Prevent disk pressure evictions |

## Alerting Rules

### Critical Alerts
```yaml
# OOM Kill alert
- alert: ContainerOOMKilled
  expr: kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} > 0
  for: 0m
  labels:
    severity: critical
  annotations:
    summary: "Container {{ $labels.container }} OOM killed in pod {{ $labels.pod }}"

# Pod crash loop
- alert: PodCrashLooping
  expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Pod {{ $labels.pod }} is crash looping"
```

### Warning Alerts
```yaml
# High CPU usage
- alert: HighCPUUsage
  expr: rate(container_cpu_usage_seconds_total[5m]) > 0.9
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Container {{ $labels.container }} sustained high CPU usage"

# High memory usage
- alert: HighMemoryUsage
  expr: container_memory_working_set_bytes / container_spec_memory_limit_bytes > 0.85
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Container {{ $labels.container }} memory usage above 85% of limit"
```

## Integration with Dev Environments (Part 2)

For per-user development environments, monitoring extends to:
- **Resource accuracy:** Compare requested vs. actual resource usage per pod
- **Idle detection:** Alert when a dev environment has <5% CPU for >30 minutes
- **Auto-downscaling:** VPA or custom controller to reduce resource limits on idle pods
- **Usage tracking:** Per-team/project resource consumption dashboards for chargeback
