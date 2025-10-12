#!/bin/bash

# Create Kubernetes secrets for AI Platform Infrastructure
# This script creates all necessary secrets for the development environment

set -e

NAMESPACE="ai-platform-infra"

echo "🔐 Creating Kubernetes secrets for AI Platform Infrastructure..."

# Create namespace if it doesn't exist
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# PostgreSQL Secret
echo "📊 Creating PostgreSQL secret..."
kubectl create secret generic postgresql-secret \
  --namespace=$NAMESPACE \
  --from-literal=POSTGRES_DB="ai_platform_dev" \
  --from-literal=POSTGRES_USER="postgres" \
  --from-literal=POSTGRES_PASSWORD="postgres-dev-secret-2024" \
  --from-literal=DATABASE_URL="postgresql://postgres:postgres-dev-secret-2024@postgresql:5432/ai_platform_dev" \
  --dry-run=client -o yaml | \
  kubectl label --local -f - app.kubernetes.io/managed-by=Helm -o yaml | \
  kubectl annotate --local -f - meta.helm.sh/release-name=ai-platform-infra meta.helm.sh/release-namespace=$NAMESPACE -o yaml | \
  kubectl apply -f -

# Redis Secret
echo "🔴 Creating Redis secret..."
kubectl create secret generic redis-secret \
  --namespace=$NAMESPACE \
  --from-literal=REDIS_PASSWORD="redis-dev-secret-2024" \
  --from-literal=REDIS_URL="redis://:redis-dev-secret-2024@redis:6379" \
  --dry-run=client -o yaml | kubectl apply -f -

# RabbitMQ Secret
echo "🐰 Creating RabbitMQ secret..."
kubectl create secret generic rabbitmq-secret \
  --namespace=$NAMESPACE \
  --from-literal=RABBITMQ_DEFAULT_USER="admin" \
  --from-literal=RABBITMQ_DEFAULT_PASS="rabbitmq-dev-secret-2024" \
  --from-literal=RABBITMQ_URL="amqp://admin:rabbitmq-dev-secret-2024@rabbitmq:5672" \
  --dry-run=client -o yaml | kubectl apply -f -

# ClickHouse Secret
echo "🏠 Creating ClickHouse secret..."
kubectl create secret generic clickhouse-secret \
  --namespace=$NAMESPACE \
  --from-literal=CLICKHOUSE_DB="ai_platform_dev" \
  --from-literal=CLICKHOUSE_USER="admin" \
  --from-literal=CLICKHOUSE_PASSWORD="clickhouse-dev-secret-2024" \
  --from-literal=CLICKHOUSE_URL="http://admin:clickhouse-dev-secret-2024@clickhouse:8123/ai_platform_dev" \
  --dry-run=client -o yaml | kubectl apply -f -

# InfluxDB Secret
echo "📊 Creating InfluxDB secret..."
kubectl create secret generic influxdb-secret \
  --namespace=$NAMESPACE \
  --from-literal=DOCKER_INFLUXDB_INIT_USERNAME="admin" \
  --from-literal=DOCKER_INFLUXDB_INIT_PASSWORD="influxdb-dev-secret-2024" \
  --from-literal=DOCKER_INFLUXDB_INIT_ORG="ai-platform" \
  --from-literal=DOCKER_INFLUXDB_INIT_BUCKET="metrics" \
  --from-literal=DOCKER_INFLUXDB_INIT_ADMIN_TOKEN="influxdb-dev-token-2024" \
  --from-literal=INFLUXDB_URL="http://influxdb:8086" \
  --dry-run=client -o yaml | kubectl apply -f -

# Weaviate Secret
echo "🔍 Creating Weaviate secret..."
kubectl create secret generic weaviate-secret \
  --namespace=$NAMESPACE \
  --from-literal=WEAVIATE_API_KEY="weaviate-dev-key-2024" \
  --from-literal=WEAVIATE_URL="http://weaviate:8080" \
  --dry-run=client -o yaml | kubectl apply -f -

# Docker Registry Secret
echo "🐳 Creating Docker Registry secret..."
kubectl create secret generic registry-secret \
  --namespace=$NAMESPACE \
  --from-literal=REGISTRY_HTTP_SECRET="registry-dev-secret-2024" \
  --from-literal=REGISTRY_URL="http://registry:5000" \
  --dry-run=client -o yaml | kubectl apply -f -

# NATS Secret
echo "📡 Creating NATS secret..."
kubectl create secret generic nats-secret \
  --namespace=$NAMESPACE \
  --from-literal=NATS_URL="nats://nats:4222" \
  --dry-run=client -o yaml | kubectl apply -f -

# Ray Secret (will be populated after Ray cluster is deployed)
echo "⚡ Creating Ray secret..."
kubectl create secret generic ray-secret \
  --namespace=$NAMESPACE \
  --from-literal=RAY_HEAD_SERVICE_HOST="ray-cluster-dev-head-svc" \
  --from-literal=RAY_DASHBOARD_URL="http://ray-cluster-dev-head-svc:8265" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ All secrets created successfully!"

# Verify secrets
echo ""
echo "🔍 Verifying created secrets..."
kubectl get secrets -n $NAMESPACE

echo ""
echo "🎯 Secrets are ready for deployment!"
echo "   Run: ./deploy-dev-simple.sh to deploy the infrastructure"