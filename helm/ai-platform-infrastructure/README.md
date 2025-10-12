# AI Platform Infrastructure Helm Chart

This Helm chart deploys the complete infrastructure stack for the AI Platform, including databases, message brokers, caching, and analytics components.

## 🏗️ Architecture Overview

The chart uses a parent-child dependency model where:
- **Parent Chart**: `ai-platform-infrastructure` (this chart)
- **Dependencies**: Latest stable Bitnami charts for all components
- **Image Strategy**: Override Bitnami default images with official Docker Hub images

## 📦 Components

| Component | Official Image | Purpose |
|-----------|---------------|---------|
| PostgreSQL | `postgres:16.4` | Primary database |
| Redis | `redis:7.4` | Caching and session storage |
| RabbitMQ | `rabbitmq:3.13-management` | Message broker |
| NATS | `nats:2.10.20` | Messaging with JetStream |
| ClickHouse | `clickhouse/clickhouse-server:24.8` | Analytics database |
| Weaviate | `weaviate/weaviate:1.26.1` | Vector database |
| InfluxDB | `influxdb:2.7` | Time series database |
| Ray | `rayproject/ray:2.9.0` | Distributed computing framework |

## 🚀 Quick Start

### Prerequisites

1. Kubernetes cluster (1.24+)
2. Helm 3.8+
3. Istio service mesh installed
4. kubectl configured

### Installation

```bash
# Update dependencies
helm dependency update

# Deploy development environment
helm install ai-platform-infra . \
  -f values-dev.yaml \
  --namespace ai-platform-infra-dev \
  --create-namespace

# Deploy production environment
helm install ai-platform-infra . \
  -f values-prod.yaml \
  --namespace ai-platform-infra \
  --create-namespace
```

## 🔧 Configuration

### Environment-Specific Values

#### Development (`values-dev.yaml`)
- Single instance deployments
- Minimal resource allocation
- Simplified authentication
- 5-10GB storage per component

#### Production (`values-prod.yaml`)
- High availability with clustering
- Production-grade resources
- Full authentication and security
- 20-200GB storage per component

## 🎯 Critical Image Override Configuration

### PostgreSQL Configuration Example

```yaml
postgresql:
  enabled: true
  # CRITICAL: Override Bitnami image with official PostgreSQL
  image:
    registry: docker.io
    repository: postgres
    tag: "16.4"
    pullPolicy: IfNotPresent
  auth:
    postgresPassword: "your-secure-password"
    database: "ai_platform"
  # Development: standalone, Production: replication
  architecture: standalone  # or "replication" for prod
```

### RabbitMQ Configuration Example

```yaml
rabbitmq:
  enabled: true
  # CRITICAL: Override Bitnami image with official RabbitMQ
  image:
    registry: docker.io
    repository: rabbitmq
    tag: "3.13-management"
    pullPolicy: IfNotPresent
  auth:
    username: "admin"
    password: "your-secure-password"
  # Development: single instance, Production: clustered
  replicaCount: 1  # or 3 for prod
  clustering:
    enabled: false  # or true for prod
```

## 🔒 Security Features

### Network Policies

The chart automatically creates:
- Istio AuthorizationPolicy allowing app namespaces → infra namespace
- Kubernetes NetworkPolicy as fallback
- Namespace isolation with proper labeling

### Image Security

- **Official Images Only**: All images sourced from official repositories
- **Explicit Tags**: No `latest` tags, specific versions pinned
- **Pre-Pull Strategy**: Helm hooks ensure correct images are pulled
- **Vulnerability Scanning**: Regular updates to latest stable versions

## 🔄 Image Pre-Pull Strategy

The chart implements a comprehensive image pre-pull strategy:

1. **Pre-Install Hook**: Pulls all official images before deployment
2. **Explicit Overrides**: Values files override Bitnami defaults
3. **Validation**: Ensures correct images are used

```yaml
# Image pre-pull configuration
imagePull:
  enabled: true
  images:
    - "postgres:16.4"
    - "redis:7.4"
    - "rabbitmq:3.13-management"
    - "nats:2.10.20"
    - "clickhouse/clickhouse-server:24.8"
    - "weaviate/weaviate:1.26.1"
    - "influxdb:2.7"
```

## 🌐 Networking

### Istio Integration

```yaml
# Automatic AuthorizationPolicy creation
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-app-to-infra
  namespace: ai-platform-infra
spec:
  rules:
  - from:
    - source:
        namespaces: 
        - "ai-agents-service"
        - "auth-service"
        - "billing-service"
```

## 📊 Monitoring

All components include:
- Prometheus metrics endpoints
- Health check endpoints
- Resource monitoring
- Performance metrics

## 🔧 Maintenance

### Updating Dependencies

```bash
# Update to latest chart versions
helm dependency update

# Check for image updates
docker pull postgres:16.4
docker pull redis:7.4
# ... etc
```

### Backup Procedures

Production deployments include automated backup configurations:
- PostgreSQL: Daily backups at 2 AM
- InfluxDB: Daily backups at 1 AM
- Weaviate: Daily backups at 3 AM

## 🚨 Troubleshooting

### Common Issues

1. **Image Pull Errors**: Ensure Docker Hub access and correct tags
2. **Resource Constraints**: Adjust resource requests/limits in values files
3. **Network Policies**: Verify Istio is properly configured
4. **Storage Issues**: Check storage class availability

### Debug Commands

```bash
# Check pod status
kubectl get pods -n ai-platform-infra-dev

# View logs
kubectl logs -n ai-platform-infra-dev -l app.kubernetes.io/name=postgresql

# Check services
kubectl get svc -n ai-platform-infra-dev

# Verify network policies
kubectl get authorizationpolicies -n ai-platform-infra-dev
```

## 🚀 Ray Distributed Computing

Ray is included for distributed AI workloads. See dedicated documentation:

- **[Ray Deployment Guide](RAY_DEPLOYMENT.md)** - Complete setup and usage guide
- **[Ray Setup Summary](RAY_SETUP_SUMMARY.md)** - Quick reference

Quick deploy Ray:
```bash
./deploy-ray.sh
```

## 📚 Additional Resources

- [Infrastructure Best Practices](../INFRASTRUCTURE_BEST_PRACTICES.md)
- [Deployment Guide](../deploy-all.sh)
- [Network Policy Examples](../istio-authorization-policy-snippet.yaml)
- [Ray Deployment Guide](RAY_DEPLOYMENT.md)

## 🤝 Contributing

When contributing to this chart:
1. Always use official images
2. Pin specific versions
3. Test in development environment first
4. Update documentation
5. Follow security best practices