#!/bin/bash
# Deploy Ray with minimal standalone configuration for dev

set -e

echo "🚀 Deploying Ray with KubeRay..."

# Update Helm dependencies
echo "📦 Updating Helm dependencies..."
helm dependency update

# Deploy with dev values
echo "🎯 Installing/Upgrading ai-platform-infrastructure with Ray..."
helm upgrade --install ai-platform-infra . \
  --namespace ai-platform-infra \
  --create-namespace \
  --values values-dev.yaml \
  --wait \
  --timeout 10m

echo "✅ Ray deployment complete!"
echo ""
echo "📊 Check Ray cluster status:"
echo "  kubectl get rayclusters -n ai-platform-infra"
echo ""
echo "🔍 Check Ray pods:"
echo "  kubectl get pods -n ai-platform-infra -l app.kubernetes.io/name=kuberay"
echo ""
echo "🌐 Access Ray Dashboard (port-forward):"
echo "  kubectl port-forward -n ai-platform-infra svc/ray-cluster-head-svc 8265:8265"
echo "  Then open: http://localhost:8265"
