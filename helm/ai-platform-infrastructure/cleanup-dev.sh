#!/bin/bash

# Cleanup problematic infrastructure components for dev environment

set -e

NAMESPACE="ai-platform-infra"
RELEASE_NAME="ai-platform-infra"

echo "🧹 Cleaning up problematic infrastructure components..."

# Delete the current release
echo "🗑️  Removing current Helm release..."
helm uninstall $RELEASE_NAME --namespace $NAMESPACE || echo "Release not found, continuing..."

# Force delete problematic pods
echo "🔥 Force deleting problematic pods..."
kubectl delete pods -n $NAMESPACE --all --force --grace-period=0 || echo "No pods to delete"

# Delete persistent volume claims
echo "💾 Cleaning up persistent volume claims..."
kubectl delete pvc -n $NAMESPACE --all || echo "No PVCs to delete"

# Delete services
echo "🌐 Cleaning up services..."
kubectl delete services -n $NAMESPACE --all || echo "No services to delete"

# Delete configmaps and secrets
echo "🔐 Cleaning up configmaps and secrets..."
kubectl delete configmaps -n $NAMESPACE --all || echo "No configmaps to delete"
kubectl delete secrets -n $NAMESPACE --all || echo "No secrets to delete"

echo "✅ Cleanup completed!"

# Wait a moment for cleanup to complete
sleep 5

echo "📊 Current namespace status:"
kubectl get all -n $NAMESPACE