# KubeRay Setup Requirements for AI Platform

## Overview

This document outlines the requirements to properly configure KubeRay operator for the AI Multi-Agent Platform to enable parallel agent execution.

## Prerequisites

- KubeRay operator installed in your cluster
- Helm 3.x
- kubectl configured for your cluster
- Container registry access (GCR, ECR, or Docker Hub)

## Required Components

### 1. Custom Ray Image with AI Platform Package

**Why needed**: Ray workers need the `ai_platform` package to execute agent tasks.

**Build custom image**:

```dockerfile
# ray-ai-platform.Dockerfile
FROM rayproject/ray:2.47.1-py312

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy application code
COPY . /app
WORKDIR /app

# Install Python dependencies
RUN pip install --no-cache-dir poetry && \
    poetry config virtualenvs.create false && \
    poetry install --no-dev --no-interaction --no-ansi

# Set Python path
ENV PYTHONPATH=/app:$PYTHONPATH

# Verify installation
RUN python -c "import ai_platform; print('✅ ai_platform package installed')"
```

**Build and push**:
```bash
# Build image
docker build -f ray-ai-platform.Dockerfile -t gcr.io/${GCP_PROJECT}/ray-ai-platform:latest .

# Push to registry
docker push gcr.io/${GCP_PROJECT}/ray-ai-platform:latest
```

### 2. RayCluster Custom Resource Values

**File**: `kubernetes/ray-cluster-values.yaml`

```yaml
# Ray Cluster Configuration for AI Platform
image:
  repository: gcr.io/YOUR_PROJECT/ray-ai-platform
  tag: latest
  pullPolicy: Always

# Head node configuration
head:
  rayStartParams:
    dashboard-host: '0.0.0.0'
    port: '6379'
    object-manager-port: '8076'
    node-manager-port: '8077'
    dashboard-agent-grpc-port: '8078'
    dashboard-agent-listen-port: '52365'
    min-worker-port: '10002'
    max-worker-port: '10999'
  
  resources:
    limits:
      cpu: "4"
      memory: "8Gi"
    requests:
      cpu: "2"
      memory: "4Gi"
  
  # Environment variables for AI Platform
  envs:
    - name: PYTHONPATH
      value: "/app"
    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: ai-platform-secrets
          key: database-url
    - name: REDIS_URL
      valueFrom:
        secretKeyRef:
          name: ai-platform-secrets
          key: redis-url
    - name: NATS_URL
      value: "nats://nats.ai-platform-infra.svc.cluster.local:4222"
    - name: OPENAI_API_KEY
      valueFrom:
        secretKeyRef:
          name: ai-platform-secrets
          key: openai-api-key
          optional: true
    - name: ANTHROPIC_API_KEY
      valueFrom:
        secretKeyRef:
          name: ai-platform-secrets
          key: anthropic-api-key
          optional: true

# Worker nodes configuration
worker:
  replicas: 3
  minReplicas: 1
  maxReplicas: 10
  
  rayStartParams:
    node-manager-port: '8077'
    object-manager-port: '8076'
    dashboard-agent-grpc-port: '8078'
    dashboard-agent-listen-port: '52365'
  
  resources:
    limits:
      cpu: "4"
      memory: "8Gi"
    requests:
      cpu: "2"
      memory: "4Gi"
  
  # Same environment variables as head
  envs:
    - name: PYTHONPATH
      value: "/app"
    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: ai-platform-secrets
          key: database-url
    - name: REDIS_URL
      valueFrom:
        secretKeyRef:
          name: ai-platform-secrets
          key: redis-url
    - name: NATS_URL
      value: "nats://nats.ai-platform-infra.svc.cluster.local:4222"
    - name: OPENAI_API_KEY
      valueFrom:
        secretKeyRef:
          name: ai-platform-secrets
          key: openai-api-key
          optional: true
    - name: ANTHROPIC_API_KEY
      valueFrom:
        secretKeyRef:
          name: ai-platform-secrets
          key: anthropic-api-key
          optional: true

# Service configuration
service:
  type: ClusterIP
  port: 8265  # Dashboard port
  
# Autoscaling configuration
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

### 3. Kubernetes Secrets

**File**: `kubernetes/ai-platform-secrets.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ai-platform-secrets
  namespace: ai-platform-infra
type: Opaque
stringData:
  database-url: "postgresql://postgres:password@postgresql.ai-platform-infra.svc.cluster.local:5432/ai_platform_dev"
  redis-url: "redis://:password@redis.ai-platform-infra.svc.cluster.local:6379"
  openai-api-key: "sk-..."
  anthropic-api-key: "sk-ant-..."
```

### 4. RayCluster Custom Resource

**File**: `kubernetes/ray-cluster.yaml`

```yaml
apiVersion: ray.io/v1
kind: RayCluster
metadata:
  name: ray-cluster-ai-platform
  namespace: ai-platform-infra
spec:
  rayVersion: '2.47.1'
  
  # Head group specification
  headGroupSpec:
    serviceType: ClusterIP
    rayStartParams:
      dashboard-host: '0.0.0.0'
      port: '6379'
    template:
      spec:
        containers:
        - name: ray-head
          image: gcr.io/YOUR_PROJECT/ray-ai-platform:latest
          imagePullPolicy: Always
          ports:
          - containerPort: 6379
            name: gcs
          - containerPort: 8265
            name: dashboard
          - containerPort: 10001
            name: client
          resources:
            limits:
              cpu: "4"
              memory: "8Gi"
            requests:
              cpu: "2"
              memory: "4Gi"
          env:
          - name: PYTHONPATH
            value: "/app"
          - name: DATABASE_URL
            valueFrom:
              secretKeyRef:
                name: ai-platform-secrets
                key: database-url
          - name: REDIS_URL
            valueFrom:
              secretKeyRef:
                name: ai-platform-secrets
                key: redis-url
          - name: NATS_URL
            value: "nats://nats.ai-platform-infra.svc.cluster.local:4222"
          - name: OPENAI_API_KEY
            valueFrom:
              secretKeyRef:
                name: ai-platform-secrets
                key: openai-api-key
                optional: true
          - name: ANTHROPIC_API_KEY
            valueFrom:
              secretKeyRef:
                name: ai-platform-secrets
                key: anthropic-api-key
                optional: true
  
  # Worker group specification
  workerGroupSpecs:
  - groupName: worker-group
    replicas: 3
    minReplicas: 1
    maxReplicas: 10
    rayStartParams: {}
    template:
      spec:
        containers:
        - name: ray-worker
          image: gcr.io/YOUR_PROJECT/ray-ai-platform:latest
          imagePullPolicy: Always
          resources:
            limits:
              cpu: "4"
              memory: "8Gi"
            requests:
              cpu: "2"
              memory: "4Gi"
          env:
          - name: PYTHONPATH
            value: "/app"
          - name: DATABASE_URL
            valueFrom:
              secretKeyRef:
                name: ai-platform-secrets
                key: database-url
          - name: REDIS_URL
            valueFrom:
              secretKeyRef:
                name: ai-platform-secrets
                key: redis-url
          - name: NATS_URL
            value: "nats://nats.ai-platform-infra.svc.cluster.local:4222"
          - name: OPENAI_API_KEY
            valueFrom:
              secretKeyRef:
                name: ai-platform-secrets
                key: openai-api-key
                optional: true
          - name: ANTHROPIC_API_KEY
            valueFrom:
              secretKeyRef:
                name: ai-platform-secrets
                key: anthropic-api-key
                optional: true
```

### 5. Service for External Access

**File**: `kubernetes/ray-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ray-cluster-dev-head-svc
  namespace: ai-platform-infra
spec:
  type: ClusterIP
  selector:
    ray.io/cluster: ray-cluster-ai-platform
    ray.io/node-type: head
  ports:
  - name: dashboard
    port: 8265
    targetPort: 8265
  - name: client
    port: 10001
    targetPort: 10001
  - name: gcs
    port: 6379
    targetPort: 6379
```

## Deployment Steps

### 1. Create Secrets
```bash
kubectl apply -f kubernetes/ai-platform-secrets.yaml
```

### 2. Build and Push Custom Image
```bash
# Build
docker build -f ray-ai-platform.Dockerfile -t gcr.io/${GCP_PROJECT}/ray-ai-platform:latest .

# Push
docker push gcr.io/${GCP_PROJECT}/ray-ai-platform:latest
```

### 3. Deploy RayCluster
```bash
kubectl apply -f kubernetes/ray-cluster.yaml
```

### 4. Verify Deployment
```bash
# Check Ray cluster status
kubectl get raycluster -n ai-platform-infra

# Check pods
kubectl get pods -n ai-platform-infra -l ray.io/cluster=ray-cluster-ai-platform

# Check logs
kubectl logs -n ai-platform-infra -l ray.io/node-type=head -c ray-head

# Test connection
kubectl port-forward -n ai-platform-infra svc/ray-cluster-dev-head-svc 8265:8265 10001:10001
```

### 5. Test Ray Connection
```bash
poetry run python -c "
import ray
ray.init(address='ray://localhost:10001')
print('✅ Connected to Ray cluster')
print(f'Nodes: {ray.nodes()}')
ray.shutdown()
"
```

## Key Requirements Summary

1. **Custom Docker Image**: Must include ai_platform package and all dependencies
2. **Environment Variables**: Database, Redis, NATS, and AI provider credentials
3. **PYTHONPATH**: Set to `/app` so Python can find ai_platform module
4. **Resources**: Adequate CPU/memory for parallel agent execution
5. **Networking**: Services exposed for dashboard (8265) and client (10001)
6. **Secrets**: Secure storage of credentials and connection strings
7. **Python Version**: Match between local (3.12.8) and Ray cluster (3.12.9) - use 3.12.9 in Dockerfile

## Testing Checklist

- [ ] Custom Ray image builds successfully
- [ ] Image pushed to container registry
- [ ] Secrets created in cluster
- [ ] RayCluster deployed and running
- [ ] Head node is healthy
- [ ] Worker nodes are healthy
- [ ] Port forwarding works
- [ ] Can connect via ray.init()
- [ ] Can import ai_platform in Ray workers
- [ ] Environment variables accessible in workers
- [ ] Database connection works from workers
- [ ] AI provider APIs accessible from workers

## Troubleshooting

### Issue: "No module named 'ai_platform'"
**Solution**: Rebuild custom image with package installed

### Issue: "Connection refused"
**Solution**: Check port forwarding and service configuration

### Issue: "Database connection failed"
**Solution**: Verify DATABASE_URL secret and network policies

### Issue: "Python version mismatch"
**Solution**: Use Python 3.12.9 in Dockerfile to match cluster

## CI/CD Integration

Add to your CI/CD pipeline:

```yaml
# .github/workflows/deploy-ray.yml
- name: Build Ray Image
  run: |
    docker build -f ray-ai-platform.Dockerfile \
      -t gcr.io/${{ secrets.GCP_PROJECT }}/ray-ai-platform:${{ github.sha }} \
      -t gcr.io/${{ secrets.GCP_PROJECT }}/ray-ai-platform:latest .
    
- name: Push Ray Image
  run: |
    docker push gcr.io/${{ secrets.GCP_PROJECT }}/ray-ai-platform:${{ github.sha }}
    docker push gcr.io/${{ secrets.GCP_PROJECT }}/ray-ai-platform:latest

- name: Update RayCluster
  run: |
    kubectl set image raycluster/ray-cluster-ai-platform \
      ray-head=gcr.io/${{ secrets.GCP_PROJECT }}/ray-ai-platform:${{ github.sha }} \
      ray-worker=gcr.io/${{ secrets.GCP_PROJECT }}/ray-ai-platform:${{ github.sha }} \
      -n ai-platform-infra
```

## References

- [KubeRay Documentation](https://docs.ray.io/en/latest/cluster/kubernetes/index.html)
- [Ray on Kubernetes Guide](https://docs.ray.io/en/latest/cluster/kubernetes/getting-started.html)
- [RayCluster CRD Reference](https://ray-project.github.io/kuberay/reference/api/)
