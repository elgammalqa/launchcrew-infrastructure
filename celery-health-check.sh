#!/bin/bash

# Celery Health Check Script
# Comprehensive health check for all Celery components

set -e

NAMESPACE="ai-platform-infra"

echo "🔍 Celery Deployment Health Check"
echo "=================================="

# Check pod status
echo ""
echo "📊 Pod Status:"
kubectl get pods -n $NAMESPACE -l 'app.kubernetes.io/component in (celery-worker,celery-beat,celery-flower)' -o wide

# Check services
echo ""
echo "🌐 Services:"
kubectl get svc -n $NAMESPACE -l 'app.kubernetes.io/component in (celery-flower)'

# Test Redis connectivity
echo ""
echo "🔍 Testing Redis connectivity..."
WORKER_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=celery-worker -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n $NAMESPACE $WORKER_POD -- python -c "
import redis
r = redis.Redis(host='redis', port=6379, db=0, password='redis-dev-secret-2024')
print('✅ Redis connection:', r.ping())
print('📊 Queue length:', r.llen('celery'))
"

# Check worker logs (last 5 lines)
echo ""
echo "📋 Worker Logs (last 5 lines):"
kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=celery-worker --tail=5

# Check beat logs (last 5 lines)
echo ""
echo "📋 Beat Logs (last 5 lines):"
kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=celery-beat --tail=5

# Test task processing
echo ""
echo "🧪 Testing task processing..."
kubectl cp test-celery-simple.py $NAMESPACE/$WORKER_POD:/tmp/test-celery-simple.py
kubectl exec -n $NAMESPACE $WORKER_POD -- python /tmp/test-celery-simple.py

echo ""
echo "🎉 Celery Health Check Complete!"
echo ""
echo "🔧 Access Commands:"
echo "   # Access Flower monitoring:"
echo "   kubectl port-forward -n $NAMESPACE svc/ai-celery-flower 5555:5555"
echo "   # Then open: http://localhost:5555"
echo "   # Username: admin, Password: flower-dev-secret-2024"
echo ""
echo "   # Scale workers:"
echo "   kubectl scale deployment ai-celery-worker -n $NAMESPACE --replicas=3"
echo ""
echo "   # Monitor logs:"
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=celery-worker -f"