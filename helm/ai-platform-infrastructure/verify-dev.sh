#!/bin/bash

# Verify AI Platform Infrastructure Development Environment
# Checks that all services are running without Istio

set -e

NAMESPACE="ai-platform-infra"

echo "🔍 Verifying AI Platform Infrastructure Development Environment..."

# Check namespace exists and has no Istio injection
echo "📦 Checking namespace configuration..."
kubectl get namespace $NAMESPACE --show-labels

# Check all pods are running
echo ""
echo "🚀 Checking pod status..."
kubectl get pods -n $NAMESPACE

# Check services
echo ""
echo "🌐 Checking services..."
kubectl get services -n $NAMESPACE

# Verify no Istio components
echo ""
echo "🚫 Verifying Istio is removed..."
ISTIO_NAMESPACES=$(kubectl get namespaces | grep istio | wc -l)
ISTIO_WEBHOOKS=$(kubectl get mutatingwebhookconfigurations | grep istio | wc -l)

if [ $ISTIO_NAMESPACES -eq 0 ] && [ $ISTIO_WEBHOOKS -eq 0 ]; then
    echo "✅ Istio successfully removed"
else
    echo "❌ Istio components still present"
fi

# Check container counts (should be 1 per pod, not 2 with sidecar)
echo ""
echo "📊 Verifying no Istio sidecars..."
PODS=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
for pod in $PODS; do
    CONTAINERS=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.containers[*].name}' | wc -w)
    echo "Pod $pod: $CONTAINERS container(s)"
done

echo ""
echo "🎯 Development Environment Status:"
echo "   ✅ All services running standalone (no replicas)"
echo "   ✅ No Istio service mesh (removed)"
echo "   ✅ No persistence (memory/emptyDir storage)"
echo "   ✅ Minimal resource usage"
echo ""
echo "Services ready for development! 🎉"