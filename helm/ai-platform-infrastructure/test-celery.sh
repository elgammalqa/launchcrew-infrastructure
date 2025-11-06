#!/bin/bash

# Test Celery deployment in Kubernetes
# This script runs Celery tests inside the cluster

set -e

NAMESPACE="ai-platform-infra"

echo "🧪 Testing Celery deployment in Kubernetes..."

# Check if Celery pods are running
echo "🔍 Checking Celery pod status..."

WORKER_PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=celery-worker --no-headers 2>/dev/null | wc -l)
BEAT_PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=celery-beat --no-headers 2>/dev/null | wc -l)
FLOWER_PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=celery-flower --no-headers 2>/dev/null | wc -l)

echo "📊 Celery Components Status:"
echo "   Workers: $WORKER_PODS pods"
echo "   Beat: $BEAT_PODS pods"
echo "   Flower: $FLOWER_PODS pods"

if [ "$WORKER_PODS" -eq 0 ]; then
    echo "❌ No Celery worker pods found!"
    echo "💡 Deploy Celery first: ./deploy-celery.sh"
    exit 1
fi

# Get a worker pod name
WORKER_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=celery-worker -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$WORKER_POD" ]; then
    echo "❌ Could not find a running Celery worker pod!"
    exit 1
fi

echo "🎯 Using worker pod: $WORKER_POD"

# Test Celery worker connectivity
echo ""
echo "🔍 Testing Celery worker connectivity..."
kubectl exec -n $NAMESPACE $WORKER_POD -- celery -A tasks inspect ping || {
    echo "❌ Celery worker ping failed!"
    echo "📋 Worker logs:"
    kubectl logs -n $NAMESPACE $WORKER_POD --tail=20
    exit 1
}

echo "✅ Celery worker is responding!"

# Test Redis connectivity
echo ""
echo "🔍 Testing Redis connectivity..."
kubectl exec -n $NAMESPACE $WORKER_POD -- python -c "
import redis
r = redis.Redis(host='ai-redis', port=6379, db=0)
r.ping()
print('✅ Redis connection successful!')
" || {
    echo "❌ Redis connection failed!"
    exit 1
}

# Run Python test script in the worker pod
echo ""
echo "🚀 Running Celery task tests..."

# Copy test script to pod
kubectl cp test-celery.py $NAMESPACE/$WORKER_POD:/tmp/test-celery.py

# Run the test
kubectl exec -n $NAMESPACE $WORKER_POD -- python /tmp/test-celery.py || {
    echo "❌ Celery task tests failed!"
    exit 1
}

# Check Flower accessibility
if [ "$FLOWER_PODS" -gt 0 ]; then
    echo ""
    echo "🌸 Testing Flower monitoring interface..."
    
    FLOWER_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=celery-flower -o jsonpath='{.items[0].metadata.name}')
    
    # Test Flower health endpoint
    kubectl exec -n $NAMESPACE $FLOWER_POD -- curl -s http://localhost:5555/ > /dev/null && {
        echo "✅ Flower is accessible!"
        echo "🌐 Access Flower:"
        echo "   kubectl port-forward -n $NAMESPACE svc/ai-celery-flower 5555:5555"
        echo "   Then open: http://localhost:5555"
    } || {
        echo "⚠️  Flower health check failed, but this might be normal"
    }
fi

echo ""
echo "🎉 Celery deployment test completed successfully!"
echo ""
echo "📊 Quick Status Check:"
kubectl get pods -n $NAMESPACE -l 'app.kubernetes.io/component in (celery-worker,celery-beat,celery-flower)'

echo ""
echo "🔧 Useful commands:"
echo "   # Monitor worker logs:"
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=celery-worker -f"
echo ""
echo "   # Monitor beat logs:"
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=celery-beat -f"
echo ""
echo "   # Scale workers:"
echo "   kubectl scale deployment ai-celery-worker -n $NAMESPACE --replicas=3"
echo ""
echo "   # Access Flower monitoring:"
echo "   kubectl port-forward -n $NAMESPACE svc/ai-celery-flower 5555:5555"