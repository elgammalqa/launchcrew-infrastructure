#!/bin/bash

# Complete deployment script for AI Platform Infrastructure
# Handles secrets, namespace management, and Helm deployment

set -e

NAMESPACE="ai-platform-infra"
RELEASE_NAME="ai-platform-infra"
CHART_PATH="."

echo "🚀 Starting complete AI Platform Infrastructure deployment..."

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed. Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not available. Please install kubectl first."
    exit 1
fi

# Check if we can connect to Kubernetes cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

echo "✅ Prerequisites check passed"

# Step 1: Create namespace and clean up existing secrets
echo ""
echo "🔐 Step 1: Creating namespace and cleaning up existing secrets..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl delete secrets --all -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true

# Step 2: Add required Helm repositories
echo ""
echo "📦 Step 2: Adding Helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm repo add weaviate https://weaviate.github.io/weaviate-helm
helm repo add influxdata https://helm.influxdata.com/
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update

# Step 3: Clean up any existing release
echo ""
echo "🧹 Step 3: Cleaning up existing Helm release..."
helm uninstall $RELEASE_NAME -n $NAMESPACE --ignore-not-found 2>/dev/null || true

# Wait a moment for cleanup
sleep 5

# Step 4: Deploy infrastructure services
echo ""
echo "🔧 Step 4: Deploying infrastructure services..."
helm install $RELEASE_NAME $CHART_PATH \
  --namespace $NAMESPACE \
  --values values-dev.yaml \
  --timeout 15m \
  --wait

# Step 5: Wait for KubeRay operator to be ready
echo ""
echo "⏳ Step 5: Waiting for KubeRay operator to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kuberay-operator -n $NAMESPACE --timeout=120s

# Step 6: Enable Ray cluster
echo ""
echo "🔧 Step 6: Deploying Ray cluster..."
helm upgrade $RELEASE_NAME $CHART_PATH \
  --namespace $NAMESPACE \
  --values values-dev.yaml \
  --set rayCluster.enabled=true \
  --timeout 15m \
  --wait

# Step 7: Wait for all pods to be ready
echo ""
echo "⏳ Step 7: Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pod --all -n $NAMESPACE --timeout=300s

# Step 8: Health checks
echo ""
echo "🏥 Step 8: Running health checks..."

check_service_health() {
  local service=$1
  local port=$2
  
  echo "🔍 Checking $service health..."
  
  if kubectl get pods -n $NAMESPACE -l component=$service | grep -q "Running"; then
    echo "  ✅ $service pod is running"
  else
    echo "  ❌ $service pod is not running"
    kubectl get pods -n $NAMESPACE -l component=$service
  fi
}

# Check all services
check_service_health "postgresql" "5432"
check_service_health "redis" "6379"
check_service_health "rabbitmq" "5672"
check_service_health "nats" "4222"
check_service_health "clickhouse" "8123"
check_service_health "weaviate" "8080"
check_service_health "influxdb" "8086"
check_service_health "registry" "5000"

# Check Ray cluster
echo "🔍 Checking Ray cluster health..."
if kubectl get raycluster -n $NAMESPACE 2>/dev/null | grep -q "ray-cluster-dev"; then
  echo "  ✅ Ray cluster is deployed"
else
  echo "  ⚠️  Ray cluster not found"
fi

# Step 9: Display status and connection info
echo ""
echo "📊 Step 9: Deployment status..."
echo ""
echo "Pods:"
kubectl get pods -n $NAMESPACE -o wide

echo ""
echo "Services:"
kubectl get services -n $NAMESPACE

echo ""
echo "Secrets:"
kubectl get secrets -n $NAMESPACE

echo ""
echo "🎯 AI Platform Infrastructure deployment completed successfully!"
echo ""
echo "🔗 Service connection commands:"
echo "   PostgreSQL:    kubectl port-forward -n $NAMESPACE svc/postgresql 5432:5432"
echo "   Redis:         kubectl port-forward -n $NAMESPACE svc/redis 6379:6379"
echo "   RabbitMQ Mgmt: kubectl port-forward -n $NAMESPACE svc/rabbitmq 15672:15672"
echo "   NATS:          kubectl port-forward -n $NAMESPACE svc/nats 4222:4222"
echo "   ClickHouse:    kubectl port-forward -n $NAMESPACE svc/clickhouse 8123:8123"
echo "   Weaviate:      kubectl port-forward -n $NAMESPACE svc/weaviate 8080:8080"
echo "   InfluxDB:      kubectl port-forward -n $NAMESPACE svc/influxdb 8086:8086"
echo "   Registry:      kubectl port-forward -n $NAMESPACE svc/registry 5000:5000"
echo "   Ray Dashboard: kubectl port-forward -n $NAMESPACE svc/ray-cluster-dev-head-svc 8265:8265"
echo ""
echo "🔐 Access credentials:"
echo "   Get all secrets: ./get-secrets.sh all"
echo "   Generate .env:   ./get-secrets.sh env > .env"
echo ""
echo "🔧 Management commands:"
echo "   View logs:    kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=ai-platform-infrastructure"
echo "   Restart all:  kubectl rollout restart deployment -n $NAMESPACE"
echo "   Delete all:   helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo ""
echo "✅ Deployment complete! All services are running in namespace: $NAMESPACE"