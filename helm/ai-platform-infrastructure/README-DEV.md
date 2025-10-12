# AI Platform Infrastructure - Development Environment

This directory contains Helm charts for deploying AI Platform infrastructure components in a development environment.

## Development Configuration

The development environment is configured to:
- **Minimize resource usage** - Only essential services run
- **Disable persistence** - No data persistence (faster startup, data lost on restart)
- **Use latest stable images** - Always pull from Docker Hub
- **Zero replicas for heavy services** - ClickHouse, Weaviate, etc. are disabled

## Quick Start

### 1. Cleanup existing deployment (if needed)
```bash
./cleanup-dev.sh
```

### 2. Deploy development infrastructure
```bash
./deploy-dev.sh
```

### 3. Check status
```bash
kubectl get pods -n ai-platform-infra
kubectl get services -n ai-platform-infra
```

## Services

### Enabled for Dev
- **InfluxDB2** - Time-series database for metrics
  - Port: 8086
  - Access: `kubectl port-forward -n ai-platform-infra svc/ai-platform-infra-influxdb2 8086:8086`

### Disabled for Dev
- **PostgreSQL** - Use external database or SQLite for dev
- **Redis** - Use in-memory cache or external Redis
- **RabbitMQ** - Use external message broker or disable messaging
- **NATS** - Use external NATS or disable streaming
- **ClickHouse** - Use external analytics DB or disable analytics
- **Weaviate** - Use external vector DB or disable vector search

## Configuration Files

- `values.yaml` - Base configuration
- `values-dev.yaml` - Development overrides
- `Chart.yaml` - Helm chart definition

## Troubleshooting

### ImagePullBackOff errors
- Check if images exist on Docker Hub
- Verify image tags are correct
- Ensure network connectivity

### CrashLoopBackOff errors
- Check pod logs: `kubectl logs -n ai-platform-infra <pod-name>`
- Verify resource limits
- Check configuration values

### Resource issues
- Reduce resource requests in values-dev.yaml
- Disable more services if needed
- Use external services instead

## External Services for Dev

For development, consider using external services:
- **PostgreSQL**: Local Docker container or cloud service
- **Redis**: Local Docker container or cloud service
- **Message Queue**: Disable or use cloud service
- **Vector DB**: Disable or use cloud service