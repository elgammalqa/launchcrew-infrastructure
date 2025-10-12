# Ray Deployment Guide

This guide covers deploying Ray using KubeRay with minimal standalone configuration for development.

## Overview

Ray is deployed using the Bitnami KubeRay Helm chart with:
- **Standalone mode**: Single head node + 1 worker
- **Minimal resources**: Optimized for local dev (Kind/Minikube)
- **No autoscaling**: Fixed cluster size for predictability

## Architecture

```
┌─────────────────────────────────────┐
│     KubeRay Operator                │
│  (Manages Ray Clusters)             │
└─────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│     Ray Cluster                     │
│                                     │
│  ┌──────────────┐  ┌─────────────┐ │
│  │  Head Node   │  │   Worker    │ │
│  │  - Dashboard │  │   - 1 CPU   │ │
│  │  - 1 CPU     │  │   - 2Gi RAM │ │
│  │  - 2Gi RAM   │  │             │ │
│  └──────────────┘  └─────────────┘ │
└─────────────────────────────────────┘
```

## Quick Start

### 1. Deploy Ray

```bash
cd infrastructure/helm/ai-platform-infrastructure
./deploy-ray.sh
```

### 2. Verify Deployment

```bash
# Check Ray cluster
kubectl get rayclusters -n ai-platform-infra

# Check pods
kubectl get pods -n ai-platform-infra -l app.kubernetes.io/name=kuberay

# Check services
kubectl get svc -n ai-platform-infra | grep ray
```

### 3. Access Ray Dashboard

```bash
# Port forward to Ray dashboard
kubectl port-forward -n ai-platform-infra svc/ray-cluster-head-svc 8265:8265

# Open in browser
open http://localhost:8265
```

## Configuration

### Minimal Dev Configuration (values-dev.yaml)

```yaml
kuberay:
  enabled: true
  rayCluster:
    worker:
      replicas: 1  # Single worker for dev
```

### Full Configuration (values.yaml)

The main values.yaml contains:
- **Operator**: KubeRay operator with minimal resources
- **Head Node**: 1 CPU, 2Gi RAM, Ray 2.9.0
- **Worker Node**: 1 replica, 1 CPU, 2Gi RAM
- **Services**: ClusterIP for client (10001), dashboard (8265), GCS (6379)
- **Autoscaling**: Disabled for dev

## Using Ray

### Connect from Python

```python
import ray

# Connect to Ray cluster
ray.init(address="ray://ray-cluster-head-svc.ai-platform-infra.svc.cluster.local:10001")

# Run distributed task
@ray.remote
def hello_world():
    return "Hello from Ray!"

# Execute
result = ray.get(hello_world.remote())
print(result)
```

### Submit Ray Job

```bash
# Port forward Ray client port
kubectl port-forward -n ai-platform-infra svc/ray-cluster-head-svc 10001:10001

# Submit job
ray job submit --address http://localhost:8265 -- python my_script.py
```

## Resource Requirements

### Minimal (Dev)
- **Head Node**: 500m CPU, 1Gi RAM (requests) / 1 CPU, 2Gi RAM (limits)
- **Worker Node**: 500m CPU, 1Gi RAM (requests) / 1 CPU, 2Gi RAM (limits)
- **Operator**: 100m CPU, 128Mi RAM (requests) / 500m CPU, 512Mi RAM (limits)
- **Total**: ~1.1 CPU, ~2.3Gi RAM

### Scaling Up (Production)

To scale for production, update values.yaml:

```yaml
kuberay:
  rayCluster:
    worker:
      replicas: 3  # More workers
    autoscaling:
      enabled: true
      minReplicas: 1
      maxReplicas: 10
```

## Troubleshooting

### Check Operator Logs
```bash
kubectl logs -n ai-platform-infra -l app.kubernetes.io/name=kuberay-operator
```

### Check Head Node Logs
```bash
kubectl logs -n ai-platform-infra -l ray.io/node-type=head
```

### Check Worker Logs
```bash
kubectl logs -n ai-platform-infra -l ray.io/node-type=worker
```

### Common Issues

1. **Pods not starting**: Check resource availability
   ```bash
   kubectl describe pod -n ai-platform-infra <pod-name>
   ```

2. **Dashboard not accessible**: Verify port-forward
   ```bash
   kubectl get svc -n ai-platform-infra ray-cluster-head-svc
   ```

3. **Workers not connecting**: Check head node service
   ```bash
   kubectl logs -n ai-platform-infra -l ray.io/node-type=head
   ```

## Cleanup

```bash
# Delete Ray cluster
helm uninstall ai-platform-infra -n ai-platform-infra

# Or disable in values
# Set kuberay.enabled: false and upgrade
```

## References

- [KubeRay Documentation](https://docs.ray.io/en/latest/cluster/kubernetes/index.html)
- [Bitnami KubeRay Chart](https://github.com/bitnami/charts/tree/main/bitnami/kuberay)
- [Ray Documentation](https://docs.ray.io/)
