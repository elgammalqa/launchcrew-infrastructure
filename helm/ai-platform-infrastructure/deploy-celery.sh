#!/bin/bash

# Deploy Celery components to AI Platform Infrastructure
# This script deploys Celery workers, beat scheduler, and Flower monitoring

set -e

NAMESPACE="ai-platform-infra"
RELEASE_NAME="ai"

echo "🚀 Deploying Celery to AI Platform Infrastructure..."

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    echo "📦 Creating namespace: $NAMESPACE"
    kubectl create namespace $NAMESPACE
fi

# Check if Redis is running (required for Celery)
echo "🔍 Checking Redis availability..."
if ! kubectl get deployment ai-redis -n $NAMESPACE >/dev/null 2>&1; then
    echo "❌ Redis is not deployed. Please deploy Redis first:"
    echo "   ./deploy-dev.sh"
    exit 1
fi

# Update Helm dependencies
echo "📦 Updating Helm dependencies..."
helm dependency update

# Deploy with Celery enabled
echo "🚀 Deploying Celery components..."
helm upgrade --install $RELEASE_NAME . \
    --namespace $NAMESPACE \
    --values values-dev.yaml \
    --set celery.worker.enabled=true \
    --set celery.beat.enabled=true \
    --set celery.flower.enabled=true \
    --wait \
    --timeout=10m

echo "✅ Celery deployment completed!"

# Show deployment status
echo ""
echo "📊 Deployment Status:"
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=celery-worker
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=celery-beat
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=celery-flower

echo ""
echo "🌐 Access Celery Flower monitoring:"
echo "   kubectl port-forward -n $NAMESPACE svc/ai-celery-flower 5555:5555"
echo "   Then open: http://localhost:5555"
echo "   Username: admin"
echo "   Password: flower-dev-secret-2024"

echo ""
echo "🔧 Useful commands:"
echo "   # Check Celery worker logs"
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=celery-worker -f"
echo ""
echo "   # Check Celery beat logs"
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=celery-beat -f"
echo ""
echo "   # Scale Celery workers"
echo "   kubectl scale deployment ai-celery-worker -n $NAMESPACE --replicas=3"