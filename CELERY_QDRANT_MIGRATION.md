# Celery and Qdrant Infrastructure Migration

## Overview

This document outlines the migration of Celery worker infrastructure and Qdrant vector database from the ai-agents service to the centralized infrastructure management under `infrastructure/helm/ai-platform-infrastructure`.

## What Was Moved

### 1. Docker Files
- **From**: `ai-agents/docker/`
- **To**: `infrastructure/docker/`
- **Files**:
  - `celery-worker-production.dockerfile` - Production-ready Celery worker with GKE deployment capabilities
  - `celery-worker.dockerfile` - Multi-stage Celery worker with supervisor management

### 2. Cloud Build Configuration
- **From**: `ai-agents/cloudbuild-worker.yaml`
- **To**: `infrastructure/cloudbuild-worker.yaml`
- **Updates**: 
  - Uses new Docker file path
  - Deploys complete infrastructure (not just Celery)
  - Includes Qdrant, PostgreSQL, Redis, and all dependencies

### 3. Kubernetes Manifests
- **From**: `ai-agents/k8s/celery-worker-deployment.yaml`
- **To**: `infrastructure/helm/ai-platform-infrastructure/templates/simple-celery.yaml`
- **Improvements**:
  - Helm templated for reusability
  - Integrated with existing values structure
  - Supports Celery worker, beat, and flower components

### 4. Helm Templates
- **Added**: `infrastructure/helm/ai-platform-infrastructure/templates/simple-qdrant.yaml`
- **Added**: `infrastructure/helm/ai-platform-infrastructure/templates/simple-celery.yaml`
- **Updated**: `infrastructure/helm/ai-platform-infrastructure/templates/_helpers.tpl`

## Configuration Structure

### Values Configuration
The Celery and Qdrant configurations are managed through:
- **Base values**: `infrastructure/helm/ai-platform-infrastructure/values.yaml` (disabled by default)
- **Dev values**: `infrastructure/helm/ai-platform-infrastructure/values-dev.yaml` (enabled with full config)

### Key Components Deployed

#### Celery Infrastructure
1. **Celery Workers** - AI task processing with real agent execution
2. **Celery Beat** - Scheduled task management
3. **Celery Flower** - Monitoring and management UI
4. **Redis Broker** - Task queue and result backend

#### Qdrant Vector Database
1. **Qdrant Service** - Vector database for semantic caching
2. **Persistent Storage** - Optional for production environments
3. **Health Checks** - Automated monitoring and recovery

#### Supporting Services
1. **PostgreSQL** - Workflow state persistence
2. **Redis** - Caching and Celery broker
3. **RabbitMQ** - Alternative message broker
4. **NATS** - Event streaming
5. **InfluxDB** - Metrics storage

## Deployment Methods

### 1. Complete Infrastructure Deployment
```bash
# Deploy everything including Celery and Qdrant
./infrastructure/deploy-ai-platform-infrastructure.sh
```

### 2. Helm-based Deployment
```bash
# Using Helm directly
helm install ai-platform-infra ./infrastructure/helm/ai-platform-infrastructure \
  --namespace ai-platform-infra \
  --create-namespace \
  --values ./infrastructure/helm/ai-platform-infrastructure/values-dev.yaml \
  --set celery.worker.enabled=true \
  --set simpleServices.qdrant.enabled=true
```

### 3. Cloud Build Deployment
```bash
# Build and deploy Celery workers with complete infrastructure
gcloud builds submit --config infrastructure/cloudbuild-worker.yaml
```

## Service Connectivity

### Celery Services
- **Workers**: Internal service communication
- **Flower UI**: `kubectl port-forward -n ai-platform-infra svc/ai-celery-flower 5555:5555`
- **Redis Broker**: `kubectl port-forward -n ai-platform-infra svc/ai-redis 6379:6379`

### Qdrant Vector Database
- **HTTP API**: `kubectl port-forward -n ai-platform-infra svc/ai-qdrant 6333:6333`
- **gRPC API**: Port 6334 (internal)
- **Health Check**: `curl http://localhost:6333/`

### Database Services
- **PostgreSQL**: `kubectl port-forward -n ai-platform-infra svc/ai-postgresql 5432:5432`
- **InfluxDB**: `kubectl port-forward -n ai-platform-infra svc/ai-influxdb 8086:8086`

## Integration with AI Agents

### Environment Variables
The Celery workers are configured with:
```yaml
env:
  DATABASE_URL: "postgresql+asyncpg://postgres:postgres-dev-secret-2024@postgresql:5432/ai_platform_dev"
  REDIS_URL: "redis://:redis-dev-secret-2024@redis:6379/0"
  QDRANT_URL: "http://qdrant:6333"
  NATS_URL: "nats://nats:4222"
  RABBITMQ_URL: "amqp://admin:rabbitmq-dev-secret-2024@rabbitmq:5672"
  INFLUXDB_URL: "http://influxdb:8086"
```

### Task Processing Flow
1. **AI Agents Service** submits tasks to Celery via Redis
2. **Celery Workers** execute real AI agent tasks (not mocks)
3. **Qdrant** provides semantic caching for AI responses
4. **PostgreSQL** stores workflow state and results
5. **InfluxDB** collects metrics and performance data

## Health Monitoring

### Automated Health Checks
- **Celery Workers**: Python-based startup checks
- **Qdrant**: HTTP health endpoint monitoring
- **Database Services**: Connection and query validation
- **Redis**: Ping/pong connectivity tests

### Monitoring Tools
- **Celery Flower**: Web UI for task monitoring
- **Kubernetes Probes**: Liveness, readiness, and startup probes
- **Resource Monitoring**: CPU, memory, and storage usage

## Security Configuration

### Service Accounts
- **RBAC**: Cluster role with GKE deployment permissions
- **GCP Integration**: Workload Identity for cloud services
- **Secrets Management**: Kubernetes secrets for sensitive data

### Network Policies
- **Internal Communication**: Services communicate within namespace
- **External Access**: Controlled through port-forwarding or ingress
- **Security Context**: Non-root user execution

## Scaling and Performance

### Horizontal Pod Autoscaling
- **Celery Workers**: Scale based on CPU/memory usage
- **Queue Length**: KEDA integration for queue-based scaling
- **Resource Limits**: Configured per service component

### Resource Allocation
- **Development**: Minimal resources for cost efficiency
- **Production**: Configurable through values files
- **Storage**: Persistent volumes for stateful services

## Migration Benefits

1. **Centralized Management**: All infrastructure in one place
2. **Consistent Deployment**: Helm-based templating and configuration
3. **Scalability**: Proper resource management and autoscaling
4. **Monitoring**: Integrated health checks and observability
5. **Security**: RBAC and proper secret management
6. **Maintainability**: Clear separation of concerns

## Next Steps

1. **Update AI Agents Service**: Remove old Celery deployment scripts
2. **Configure Production**: Create production values files
3. **Monitoring Setup**: Integrate with Prometheus/Grafana
4. **Documentation**: Update deployment guides
5. **Testing**: Validate end-to-end AI agent execution

## Troubleshooting

### Common Issues
1. **Pod Startup Failures**: Check resource limits and health checks
2. **Service Connectivity**: Verify network policies and DNS resolution
3. **Storage Issues**: Ensure persistent volume claims are bound
4. **Authentication**: Validate service account permissions

### Debug Commands
```bash
# Check pod status
kubectl get pods -n ai-platform-infra

# View logs
kubectl logs -n ai-platform-infra -l app.kubernetes.io/component=celery-worker

# Test connectivity
kubectl exec -n ai-platform-infra deployment/ai-celery-worker -- python -c "import redis; print('Redis OK')"

# Check Qdrant
kubectl exec -n ai-platform-infra deployment/ai-qdrant -- curl -f http://localhost:6333/
```

This migration provides a solid foundation for scalable AI task processing with proper infrastructure management and monitoring capabilities.