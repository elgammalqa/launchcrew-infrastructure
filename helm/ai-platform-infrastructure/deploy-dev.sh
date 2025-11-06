#!/bin/bash

# Deploy AI Platform Infrastructure for Development Environment
# This script deploys standalone infrastructure components for dev (no replicas)

set -e

NAMESPACE="ai-platform-infra"
RELEASE_NAME="ai-platform-infra"
CHART_PATH="."

echo "🚀 Deploying AI Platform Infrastructure for Development (Standalone Mode)..."

# Create namespace if it doesn't exist
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Update Helm dependencies
echo "📦 Updating Helm dependencies..."
helm dependency update $CHART_PATH

# Deploy with dev values (standalone configuration)
echo "🔧 Deploying with standalone development configuration..."
helm upgrade --install $RELEASE_NAME $CHART_PATH \
  --namespace $NAMESPACE \
  --values values-dev.yaml \
  --timeout 15m \
  --wait

echo "✅ Development infrastructure deployment completed!"

# Show status
echo "📊 Checking deployment status..."
kubectl get pods -n $NAMESPACE
kubectl get services -n $NAMESPACE

echo ""
echo "🎯 Development environment is ready!"
echo "   - All services running in standalone mode (single instance each)"
echo "   - No replicas, no clustering, no persistence"
echo "   - Minimal resource usage"
echo ""
echo "Services available:"
echo "   - PostgreSQL: kubectl port-forward -n $NAMESPACE svc/ai-platform-infra-postgresql 5432:5432"
echo "   - Redis: kubectl port-forward -n $NAMESPACE svc/ai-platform-infra-redis-master 6379:6379"
echo "   - RabbitMQ: kubectl port-forward -n $NAMESPACE svc/ai-platform-infra-rabbitmq 15672:15672"
echo "   - NATS: kubectl port-forward -n $NAMESPACE svc/ai-platform-infra-nats 4222:4222"
echo "   - ClickHouse: kubectl port-forward -n $NAMESPACE svc/ai-platform-infra-clickhouse 8123:8123"
echo "   - Qdrant: kubectl port-forward -n $NAMESPACE svc/ai-platform-infra-qdrant 6333:6333"
echo "   - InfluxDB: kubectl port-forward -n $NAMESPACE svc/ai-platform-infra-influxdb2 8086:8086"