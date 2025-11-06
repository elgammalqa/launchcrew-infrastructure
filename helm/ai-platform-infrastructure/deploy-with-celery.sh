#!/bin/bash

# Deploy AI Platform Infrastructure with Celery Workers
# This script deploys the complete infrastructure including Celery workers and Qdrant

set -e

# Configuration
PROJECT_ID=${GOOGLE_CLOUD_PROJECT:-"alien-drake-474816-a2"}
REGION=${GKE_REGION:-"us-central1"}
CLUSTER_NAME=${GKE_CLUSTER_NAME:-"dev-gke-cluster"}
NAMESPACE=${NAMESPACE:-"ai-platform-infra"}
RELEASE_NAME=${RELEASE_NAME:-"ai-platform-infrastructure"}
CHART_PATH=${CHART_PATH:-"./"}

echo "=== Deploying AI Platform Infrastructure with Celery ==="
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Cluster: $CLUSTER_NAME"
echo "Namespace: $NAMESPACE"
echo "Release Name: $RELEASE_NAME"
echo "Chart Path: $CHART_PATH"
echo "========================================================="

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

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "ERROR: Helm is not installed. Please install Helm first."
    exit 1
fi

# Add required Helm repositories
echo "Adding Helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update

# Create namespace if it doesn't exist
echo "Creating namespace if it doesn't exist..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Check if Celery worker image exists
echo "Checking if Celery worker image exists..."
if ! gcloud container images describe "gcr.io/$PROJECT_ID/ai-celery-worker:latest" > /dev/null 2>&1; then
    echo "WARNING: Celery worker image not found. Building image first..."
    echo "Running: gcloud builds submit --config ../cloudbuild-worker.yaml ../../ai-agents"
    
    # Build the image using Cloud Build
    cd ../../
    gcloud builds submit --config infrastructure/cloudbuild-worker.yaml ai-agents/
    cd infrastructure/helm/ai-platform-infrastructure/
    
    echo "✅ Celery worker image built successfully"
else
    echo "✅ Celery worker image exists"
fi

# Deploy the Helm chart
echo "Deploying Helm chart..."
helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
    --namespace "$NAMESPACE" \
    --values values.yaml \
    --values values-dev.yaml \
    --set global.namespace="$NAMESPACE" \
    --set celery.enabled=true \
    --set qdrant.enabled=true \
    --set celery.config.googleCloudProject="$PROJECT_ID" \
    --set celery.config.gkeRegion="$REGION" \
    --set celery.config.gkeClusterName="$CLUSTER_NAME" \
    --wait \
    --timeout=600s

# Wait for all deployments to be ready
echo "Waiting for deployments to be ready..."

# Check PostgreSQL
if kubectl get deployment ai-platform-infrastructure-postgresql -n "$NAMESPACE" > /dev/null 2>&1; then
    echo "Waiting for PostgreSQL..."
    kubectl rollout status deployment/ai-platform-infrastructure-postgresql -n "$NAMESPACE" --timeout=300s
fi

# Check Redis
if kubectl get deployment ai-platform-infrastructure-redis-master -n "$NAMESPACE" > /dev/null 2>&1; then
    echo "Waiting for Redis..."
    kubectl rollout status deployment/ai-platform-infrastructure-redis-master -n "$NAMESPACE" --timeout=300s
fi

# Check Qdrant
if kubectl get deployment ai-platform-infrastructure-qdrant -n "$NAMESPACE" > /dev/null 2>&1; then
    echo "Waiting for Qdrant..."
    kubectl rollout status deployment/ai-platform-infrastructure-qdrant -n "$NAMESPACE" --timeout=300s
fi

# Check Celery Worker
if kubectl get deployment ai-platform-infrastructure-celery-worker -n "$NAMESPACE" > /dev/null 2>&1; then
    echo "Waiting for Celery Worker..."
    kubectl rollout status deployment/ai-platform-infrastructure-celery-worker -n "$NAMESPACE" --timeout=300s
fi

# Verify services are running
echo ""
echo "=== Deployment Status ==="
kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME"

echo ""
echo "=== Services ==="
kubectl get services -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME"

# Test Celery worker connectivity
echo ""
echo "=== Testing Celery Worker Connectivity ==="
WORKER_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/component=celery-worker" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$WORKER_POD" ] && [ "$WORKER_POD" != "" ]; then
    echo "Testing Celery ping on pod: $WORKER_POD"
    
    # Wait for pod to be ready
    kubectl wait --for=condition=Ready pod/"$WORKER_POD" -n "$NAMESPACE" --timeout=120s
    
    # Test Celery connectivity
    if kubectl exec -n "$NAMESPACE" "$WORKER_POD" -- python -c "
import sys
sys.path.append('/app')
try:
    from src.core.infrastructure.queue.celery_app import celery_app
    result = celery_app.control.ping()
    print('✅ Celery worker is responding to ping!')
    print(f'Response: {result}')
except Exception as e:
    print(f'❌ Celery worker ping failed: {e}')
    sys.exit(1)
" 2>/dev/null; then
        echo "✅ Celery worker connectivity test passed!"
    else
        echo "❌ Celery worker connectivity test failed"
        echo "Checking worker logs..."
        kubectl logs -n "$NAMESPACE" "$WORKER_POD" --tail=20
    fi
else
    echo "❌ No Celery worker pods found"
fi

# Test Qdrant connectivity
echo ""
echo "=== Testing Qdrant Connectivity ==="
QDRANT_SERVICE="ai-platform-infrastructure-qdrant"
if kubectl get service "$QDRANT_SERVICE" -n "$NAMESPACE" > /dev/null 2>&1; then
    # Test Qdrant health endpoint
    if kubectl run qdrant-test --rm -i --restart=Never --image=curlimages/curl -- \
        curl -s "http://$QDRANT_SERVICE.$NAMESPACE:6333/" > /dev/null 2>&1; then
        echo "✅ Qdrant service is accessible!"
    else
        echo "❌ Qdrant service connectivity test failed"
    fi
else
    echo "❌ Qdrant service not found"
fi

# Show useful commands
echo ""
echo "=== Useful Commands ==="
echo "Check all pods:           kubectl get pods -n $NAMESPACE"
echo "Check Celery logs:        kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=celery-worker -f"
echo "Check Qdrant logs:        kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=qdrant -f"
echo "Scale Celery workers:     kubectl scale deployment ai-platform-infrastructure-celery-worker -n $NAMESPACE --replicas=N"
echo "Port forward Qdrant:      kubectl port-forward -n $NAMESPACE svc/ai-platform-infrastructure-qdrant 6333:6333"
echo "Delete deployment:        helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo ""
echo "=== Infrastructure URLs (with port-forward) ==="
echo "Qdrant Web UI:           http://localhost:6333"
echo "PostgreSQL:              localhost:5432"
echo "Redis:                   localhost:6379"
echo ""

echo "✅ AI Platform Infrastructure deployment completed successfully!"
echo "Celery workers and Qdrant are ready to support the ai-agents service."