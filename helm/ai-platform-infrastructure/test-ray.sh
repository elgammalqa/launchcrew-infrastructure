#!/bin/bash
# Test Ray deployment

set -e

echo "🧪 Testing Ray Deployment..."
echo ""

# Check if namespace exists
echo "1️⃣ Checking namespace..."
if kubectl get namespace ai-platform-infra &> /dev/null; then
    echo "   ✅ Namespace exists"
else
    echo "   ❌ Namespace not found"
    exit 1
fi

# Check KubeRay operator
echo ""
echo "2️⃣ Checking KubeRay operator..."
OPERATOR_PODS=$(kubectl get pods -n ai-platform-infra -l app.kubernetes.io/name=kuberay-operator --no-headers 2>/dev/null | wc -l)
if [ "$OPERATOR_PODS" -gt 0 ]; then
    echo "   ✅ KubeRay operator running ($OPERATOR_PODS pod(s))"
    kubectl get pods -n ai-platform-infra -l app.kubernetes.io/name=kuberay-operator
else
    echo "   ⚠️  KubeRay operator not found (may not be deployed yet)"
fi

# Check Ray cluster
echo ""
echo "3️⃣ Checking Ray cluster..."
RAY_CLUSTERS=$(kubectl get rayclusters -n ai-platform-infra --no-headers 2>/dev/null | wc -l)
if [ "$RAY_CLUSTERS" -gt 0 ]; then
    echo "   ✅ Ray cluster(s) found:"
    kubectl get rayclusters -n ai-platform-infra
else
    echo "   ⚠️  No Ray clusters found"
fi

# Check Ray pods
echo ""
echo "4️⃣ Checking Ray pods..."
RAY_PODS=$(kubectl get pods -n ai-platform-infra -l ray.io/cluster --no-headers 2>/dev/null | wc -l)
if [ "$RAY_PODS" -gt 0 ]; then
    echo "   ✅ Ray pods running ($RAY_PODS pod(s)):"
    kubectl get pods -n ai-platform-infra -l ray.io/cluster
else
    echo "   ⚠️  No Ray pods found"
fi

# Check Ray services
echo ""
echo "5️⃣ Checking Ray services..."
RAY_SERVICES=$(kubectl get svc -n ai-platform-infra -l ray.io/cluster --no-headers 2>/dev/null | wc -l)
if [ "$RAY_SERVICES" -gt 0 ]; then
    echo "   ✅ Ray services found:"
    kubectl get svc -n ai-platform-infra -l ray.io/cluster
else
    echo "   ⚠️  No Ray services found"
fi

echo ""
echo "📊 Summary:"
echo "   - Operator pods: $OPERATOR_PODS"
echo "   - Ray clusters: $RAY_CLUSTERS"
echo "   - Ray pods: $RAY_PODS"
echo "   - Ray services: $RAY_SERVICES"
echo ""

if [ "$RAY_PODS" -gt 0 ]; then
    echo "✅ Ray is deployed and running!"
    echo ""
    echo "🌐 To access Ray Dashboard:"
    echo "   kubectl port-forward -n ai-platform-infra svc/ray-cluster-head-svc 8265:8265"
    echo "   Then open: http://localhost:8265"
else
    echo "⚠️  Ray deployment incomplete or not started"
    echo ""
    echo "To deploy Ray, run:"
    echo "   ./deploy-ray.sh"
fi
