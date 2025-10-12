# 🔐 Secrets Management

This document describes how secrets are managed in the AI Platform Infrastructure.

## Overview

All service credentials are stored as Kubernetes secrets and automatically injected into the containers as environment variables. This provides secure credential management and easy rotation.

## Available Secrets

### 🐘 PostgreSQL

- **Secret Name**: `postgresql-secret`
- **Keys**: `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `DATABASE_URL`
- **Usage**: Primary database for application data

### 🔴 Redis

- **Secret Name**: `redis-secret`
- **Keys**: `REDIS_PASSWORD`, `REDIS_URL`
- **Usage**: Caching and session storage

### 🐰 RabbitMQ

- **Secret Name**: `rabbitmq-secret`
- **Keys**: `RABBITMQ_DEFAULT_USER`, `RABBITMQ_DEFAULT_PASS`, `RABBITMQ_URL`
- **Usage**: Message queuing and async processing

### 🏠 ClickHouse

- **Secret Name**: `clickhouse-secret`
- **Keys**: `CLICKHOUSE_DB`, `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD`, `CLICKHOUSE_URL`
- **Usage**: Analytics and OLAP queries

### 📊 InfluxDB

- **Secret Name**: `influxdb-secret`
- **Keys**: `DOCKER_INFLUXDB_INIT_USERNAME`, `DOCKER_INFLUXDB_INIT_PASSWORD`, `DOCKER_INFLUXDB_INIT_ORG`, `DOCKER_INFLUXDB_INIT_BUCKET`, `DOCKER_INFLUXDB_INIT_ADMIN_TOKEN`, `INFLUXDB_URL`
- **Usage**: Time series data and metrics

### 🔍 Weaviate

- **Secret Name**: `weaviate-secret`
- **Keys**: `WEAVIATE_API_KEY`, `WEAVIATE_URL`
- **Usage**: Vector database for AI/ML applications

### 🐳 Docker Registry

- **Secret Name**: `registry-secret`
- **Keys**: `REGISTRY_HTTP_SECRET`, `REGISTRY_URL`
- **Usage**: Local container image storage

### 📡 NATS

- **Secret Name**: `nats-secret`
- **Keys**: `NATS_URL`
- **Usage**: Event streaming and messaging

### ⚡ Ray

- **Secret Name**: `ray-secret`
- **Keys**: `RAY_HEAD_SERVICE_HOST`, `RAY_DASHBOARD_URL`
- **Usage**: Distributed computing cluster

## Using Secrets

### 1. Get Individual Service Secrets

```bash
./get-secrets.sh postgresql
./get-secrets.sh redis
./get-secrets.sh rabbitmq
```

### 2. Get All Secrets

```bash
./get-secrets.sh all
```

### 3. Generate Environment File

```bash
./get-secrets.sh env > .env
```

### 4. Use in Applications

```bash
# Source the environment file
source .env

# Or use specific variables
export DATABASE_URL=$(kubectl get secret postgresql-secret -n ai-platform-infra -o jsonpath="{.data.DATABASE_URL}" | base64 -d)
```

## Manual Secret Access

### View Secret Contents

```bash
# List all secrets
kubectl get secrets -n ai-platform-infra

# Get specific secret
kubectl get secret postgresql-secret -n ai-platform-infra -o yaml

# Decode secret value
kubectl get secret postgresql-secret -n ai-platform-infra -o jsonpath="{.data.POSTGRES_PASSWORD}" | base64 -d
```

### Update Secrets

```bash
# Update a secret value
kubectl patch secret postgresql-secret -n ai-platform-infra -p='{"data":{"POSTGRES_PASSWORD":"'$(echo -n "new-password" | base64)'"}}'

# Restart deployments to pick up new secrets
kubectl rollout restart deployment -n ai-platform-infra
```

## Security Best Practices

1. **Never commit secrets to version control**
2. **Use different secrets for different environments**
3. **Rotate secrets regularly**
4. **Limit access to secrets using RBAC**
5. **Monitor secret access and usage**

## Development vs Production

### Development (Current)

- Simple passwords for easy development
- All services accessible within cluster
- Secrets stored in Kubernetes secrets

### Production Recommendations

- Use external secret management (AWS Secrets Manager, HashiCorp Vault)
- Enable encryption at rest for etcd
- Use service mesh for secure communication
- Implement secret rotation policies
- Use separate namespaces for isolation

## Troubleshooting

### Secret Not Found

```bash
# Check if secret exists
kubectl get secret <secret-name> -n ai-platform-infra

# Check secret data
kubectl describe secret <secret-name> -n ai-platform-infra
```

### Pod Can't Access Secret

```bash
# Check pod environment variables
kubectl exec <pod-name> -n ai-platform-infra -- env | grep -i <service>

# Check pod logs for authentication errors
kubectl logs <pod-name> -n ai-platform-infra
```

### Service Authentication Failed

```bash
# Verify secret values
./get-secrets.sh <service>

# Test connection manually
kubectl port-forward svc/<service> <port>:<port> -n ai-platform-infra
# Then test with retrieved credentials
```

## Helper Scripts

- `get-secrets.sh` - Retrieve and display secrets
- `registry-helper.sh` - Docker registry management
- `deploy-dev-simple.sh` - Full deployment with secrets

## Environment File Format

The generated `.env` file contains all connection strings and credentials in a format suitable for application configuration:

```bash
# PostgreSQL
DATABASE_URL=postgresql://postgres:password@postgresql:5432/ai_platform_dev

# Redis
REDIS_URL=redis://:password@redis:6379

# RabbitMQ
RABBITMQ_URL=amqp://admin:password@rabbitmq:5672

# And so on...
```

This file can be used directly with Docker Compose, application frameworks, or any system that supports environment file loading.
