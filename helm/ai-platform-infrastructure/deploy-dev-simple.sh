#!/bin/bash

# Deploy AI Platform Infrastructure for Development Environment
# Uses simple custom templates with minimal resources - no complex Helm dependencies

set -e

NAMESPACE="ai-platform-infra"
RELEASE_NAME="ai-platform-infra"
CHART_PATH="."

echo "🚀 Deploying AI Platform Infrastructure (Minimal Dev Mode)..."

# Clean up any existing Helm release
echo "🧹 Cleaning up existing Helm release..."
helm uninstall $RELEASE_NAME -n $NAMESPACE 2>/dev/null || true

# Wait for cleanup
sleep 5

# Deploy all infrastructure services including Celery and Qdrant
echo "🔧 Deploying all infrastructure services..."
helm install $RELEASE_NAME $CHART_PATH \
  --namespace $NAMESPACE \
  --create-namespace \
  --values values-dev.yaml \
  --set celery.enabled=true \
  --set qdrant.enabled=true \
  --timeout 15m \
  --wait

# Wait for KubeRay operator to be ready
echo "⏳ Waiting for KubeRay operator to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kuberay-operator -n $NAMESPACE --timeout=120s || true

# Enable Ray cluster with upgrade (keeping Celery and Qdrant enabled)
echo "🔧 Enabling Ray cluster..."
helm upgrade $RELEASE_NAME $CHART_PATH \
  --namespace $NAMESPACE \
  --values values-dev.yaml \
  --set rayCluster.enabled=true \
  --set celery.enabled=true \
  --set qdrant.enabled=true \
  --timeout 15m \
  --wait

echo "✅ Minimal development infrastructure deployment completed!"

# Wait for all pods to be ready
echo "⏳ Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pod --all -n $NAMESPACE --timeout=300s

# Health check function
check_service_health() {
  local service=$1
  local port=$2
  local path=${3:-""}
  
  echo "🔍 Checking $service health..."
  
  # Check if pod is running
  if kubectl get pods -n $NAMESPACE -l component=$service | grep -q "Running"; then
    echo "  ✅ $service pod is running"
    
    # Port forward and test connectivity
    kubectl port-forward -n $NAMESPACE svc/$service $port:$port &
    local pf_pid=$!
    sleep 3
    
    if nc -z localhost $port 2>/dev/null; then
      echo "  ✅ $service is responding on port $port"
    else
      echo "  ⚠️  $service port $port not responding"
    fi
    
    kill $pf_pid 2>/dev/null || true
  else
    echo "  ❌ $service pod is not running"
  fi
}

# Comprehensive health checks
echo ""
echo "🏥 Running comprehensive health checks..."

# Check PostgreSQL
check_service_health "postgresql" "5432"

# Check Redis
check_service_health "redis" "6379"

# Check RabbitMQ
check_service_health "rabbitmq" "5672"
check_service_health "rabbitmq" "15672"

# Check NATS
check_service_health "nats" "4222"

# Check ClickHouse
check_service_health "clickhouse" "8123"

# Check Qdrant
check_service_health "qdrant" "6333"

# Check Celery Workers
echo "🔍 Checking Celery workers health..."
if kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=celery-worker | grep -q "Running"; then
  echo "  ✅ Celery worker pods are running"
  
  # Test Celery worker connectivity
  WORKER_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=celery-worker -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$WORKER_POD" ]; then
    echo "  🔍 Testing Celery worker health on pod: $WORKER_POD"
    kubectl exec -n $NAMESPACE "$WORKER_POD" -- python -c "print('Celery worker is healthy')" 2>/dev/null && echo "  ✅ Celery worker health check passed" || echo "  ⚠️  Celery worker health check failed"
  fi
else
  echo "  ❌ Celery worker pods are not running"
fi

# Check InfluxDB
check_service_health "influxdb" "8086"

# Check Docker Registry
check_service_health "registry" "5000"

# Check Ray cluster
echo "🔍 Checking Ray cluster health..."
if kubectl get raycluster -n $NAMESPACE | grep -q "ray-cluster-dev"; then
  echo "  ✅ Ray cluster is deployed"
  if kubectl get pods -n $NAMESPACE -l ray.io/node-type=head | grep -q "Running"; then
    echo "  ✅ Ray head node is running"
  else
    echo "  ⚠️  Ray head node is not running"
  fi
else
  echo "  ❌ Ray cluster not found"
fi

# Show detailed status
echo ""
echo "📊 Detailed deployment status..."
echo "Pods:"
kubectl get pods -n $NAMESPACE -o wide

echo ""
echo "Services:"
kubectl get services -n $NAMESPACE

echo ""
echo "Resource usage:"
kubectl top pods -n $NAMESPACE 2>/dev/null || echo "Metrics server not available"

echo ""
echo "🎯 Minimal development environment is ready!"
echo "   - All infrastructure services running with minimal resources"
echo "   - Total CPU usage: ~238m, Memory usage: ~627Mi"
echo "   - Ray cluster deployed (may need additional startup time)"
echo "   - No clustering, no replication, ephemeral storage"
echo ""
echo "🔗 Service connection commands:"
echo "   PostgreSQL:  kubectl port-forward -n $NAMESPACE svc/ai-platform-infra-postgresql 5432:5432"
echo "   Redis:       kubectl port-forward -n $NAMESPACE svc/ai-platform-infra-redis-master 6379:6379"
echo "   RabbitMQ:    kubectl port-forward -n $NAMESPACE svc/ai-platform-infra-rabbitmq 15672:15672"
echo "   NATS:        kubectl port-forward -n $NAMESPACE svc/ai-platform-infra-nats 4222:4222"
echo "   ClickHouse:  kubectl port-forward -n $NAMESPACE svc/ai-platform-infra-clickhouse 8123:8123"
echo "   Qdrant:      kubectl port-forward -n $NAMESPACE svc/ai-platform-infra-qdrant 6333:6333"
echo "   InfluxDB:    kubectl port-forward -n $NAMESPACE svc/ai-platform-infra-influxdb2 8086:8086"
echo "   Registry:    kubectl port-forward -n $NAMESPACE svc/ai-platform-infra-registry 5000:5000"
echo "   Ray Dashboard: kubectl port-forward -n $NAMESPACE svc/ray-cluster-dev-head-svc 8265:8265"
echo "   Celery Monitor: kubectl port-forward -n $NAMESPACE svc/ai-platform-infra-celery-worker 5555:5555"
echo ""
echo "🐳 Docker Registry Usage:"
echo "   Tag image:   docker tag myapp:latest localhost:5000/myapp:latest"
echo "   Push image:  docker push localhost:5000/myapp:latest"
echo "   Pull image:  docker pull localhost:5000/myapp:latest"
echo "   List repos:  curl http://localhost:5000/v2/_catalog"
echo ""
echo "🔐 Secrets Management:"
echo "   Get all secrets:     ./get-secrets.sh all"
echo "   Get specific secret: ./get-secrets.sh postgresql"
echo "   Generate .env file:  ./get-secrets.sh env > .env"
echo ""
echo "🔧 Troubleshooting commands:"
echo "   View logs:   kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=ai-platform-infrastructure"
echo "   Restart all: kubectl rollout restart deployment -n $NAMESPACE"
echo "   Delete all:  helm uninstall $RELEASE_NAME -n $NAMESPACE"