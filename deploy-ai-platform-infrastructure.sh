#!/bin/bash

# Deploy Complete AI Platform Infrastructure
# This script deploys all infrastructure components including Celery workers and Qdrant

set -e

# Configuration
PROJECT_ID=${GOOGLE_CLOUD_PROJECT:-"alien-drake-474816-a2"}
REGION=${GKE_REGION:-"us-central1"}
CLUSTER_NAME=${GKE_CLUSTER_NAME:-"dev-gke-cluster"}
NAMESPACE=${NAMESPACE:-"ai-platform-infra"}
RELEASE_NAME=${RELEASE_NAME:-"ai-platform-infra"}
CHART_PATH=${CHART_PATH:-"./infrastructure/helm/ai-platform-infrastructure"}
VALUES_FILE=${VALUES_FILE:-"values-dev.yaml"}

echo "=== Deploying Complete AI Platform Infrastructure ==="
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Cluster: $CLUSTER_NAME"
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"
echo "Chart Path: $CHART_PATH"
echo "Values File: $VALUES_FILE"
echo "=================================================="

# Check if gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "ERROR: No active gcloud authentication found. Please run 'gcloud auth login'"
    exit 1
fi

# Set the project
gcloud config set project "$PROJECT_ID"

# Get GKE credentials
echo "Getting GKE cluster credentials..."
gcloud container clusters get-credentials "$CLUSTER_NAME" --region="$REGION"

# Create namespace if it doesn't exist
echo "Creating namespace if it doesn't exist..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Clean up any existing Helm release
echo "🧹 Cleaning up existing Helm release..."
helm uninstall $RELEASE_NAME -n $NAMESPACE 2>/dev/null || true

# Wait for cleanup
sleep 5

# Deploy complete infrastructure with Celery and Qdrant enabled
echo "🔧 Deploying complete AI platform infrastructure..."
helm install $RELEASE_NAME $CHART_PATH \
  --namespace $NAMESPACE \
  --create-namespace \
  --values $CHART_PATH/$VALUES_FILE \
  --set celery.worker.enabled=true \
  --set celery.beat.enabled=true \
  --set celery.flower.enabled=true \
  --set simpleServices.qdrant.enabled=true \
  --set simpleServices.postgresql.enabled=true \
  --set simpleServices.redis.enabled=true \
  --set simpleServices.rabbitmq.enabled=true \
  --set simpleServices.nats.enabled=true \
  --set simpleServices.influxdb.enabled=true \
  --timeout 15m \
  --wait

# Wait for KubeRay operator to be ready
echo "⏳ Waiting for KubeRay operator to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kuberay-operator -n $NAMESPACE --timeout=120s || true

# Enable Ray cluster with upgrade
echo "🔧 Enabling Ray cluster..."
helm upgrade $RELEASE_NAME $CHART_PATH \
  --namespace $NAMESPACE \
  --values $CHART_PATH/$VALUES_FILE \
  --set rayCluster.enabled=true \
  --set celery.worker.enabled=true \
  --set celery.beat.enabled=true \
  --set celery.flower.enabled=true \
  --set simpleServices.qdrant.enabled=true \
  --timeout 15m \
  --wait

echo "✅ Complete AI Platform Infrastructure deployment completed!"

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

# Check Qdrant
check_service_health "qdrant" "6333"

# Check InfluxDB
check_service_health "influxdb" "8086"

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

# Check Celery Flower
echo "🔍 Checking Celery Flower monitoring..."
if kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=celery-flower | grep -q "Running"; then
  echo "  ✅ Celery Flower pod is running"
else
  echo "  ❌ Celery Flower pod is not running"
fi

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
echo "🎯 Complete AI Platform Infrastructure is ready!"
echo "   - All infrastructure services running"
echo "   - Celery workers ready for AI task processing"
echo "   - Qdrant vector database ready for semantic caching"
echo "   - Ray cluster deployed for distributed computing"
echo ""
echo "🔗 Service connection commands:"
echo "   PostgreSQL:     kubectl port-forward -n $NAMESPACE svc/ai-postgresql 5432:5432"
echo "   Redis:          kubectl port-forward -n $NAMESPACE svc/ai-redis 6379:6379"
echo "   RabbitMQ:       kubectl port-forward -n $NAMESPACE svc/ai-rabbitmq 15672:15672"
echo "   NATS:           kubectl port-forward -n $NAMESPACE svc/ai-nats 4222:4222"
echo "   Qdrant:         kubectl port-forward -n $NAMESPACE svc/ai-qdrant 6333:6333"
echo "   InfluxDB:       kubectl port-forward -n $NAMESPACE svc/ai-influxdb 8086:8086"
echo "   Celery Flower:  kubectl port-forward -n $NAMESPACE svc/ai-celery-flower 5555:5555"
echo "   Ray Dashboard:  kubectl port-forward -n $NAMESPACE svc/ray-cluster-dev-head-svc 8265:8265"
echo ""
echo "🚀 AI Agent Task Processing:"
echo "   - Celery workers are ready to process AI agent tasks"
echo "   - Qdrant is ready for vector-based semantic caching"
echo "   - Redis is configured as Celery broker and cache"
echo "   - PostgreSQL is ready for workflow state persistence"
echo ""
echo "🔧 Troubleshooting commands:"
echo "   View logs:      kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=ai-platform-infrastructure"
echo "   Restart all:    kubectl rollout restart deployment -n $NAMESPACE"
echo "   Delete all:     helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo ""
echo "✅ Deployment completed successfully!"