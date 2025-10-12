#!/bin/bash

# Test Registry Script
# Demonstrates how to push and pull images from the local Docker registry

set -e

NAMESPACE="ai-platform-infra"
REGISTRY_PORT="5000"

echo "🐳 Testing Local Docker Registry"
echo ""

# Start port forwarding
echo "1. Starting port forward to registry..."
kubectl port-forward -n $NAMESPACE svc/registry $REGISTRY_PORT:$REGISTRY_PORT &
PF_PID=$!
sleep 3

# Test registry connectivity
echo "2. Testing registry connectivity..."
if curl -s http://localhost:$REGISTRY_PORT/v2/ > /dev/null; then
    echo "   ✅ Registry is accessible"
else
    echo "   ❌ Registry not accessible"
    kill $PF_PID 2>/dev/null || true
    exit 1
fi

# Check current repositories
echo "3. Current repositories in registry:"
curl -s http://localhost:$REGISTRY_PORT/v2/_catalog | jq -r '.repositories[]' 2>/dev/null || echo "   (empty)"

echo ""
echo "4. Docker Configuration Required:"
echo "   For Docker to push to insecure registries, you need to configure it."
echo ""
echo "   🔧 For Docker Desktop:"
echo "   - Go to Settings > Docker Engine"
echo "   - Add to the configuration:"
echo '   {
     "insecure-registries": ["localhost:5000"]
   }'
echo ""
echo "   🔧 For Colima:"
echo "   - Stop colima: colima stop"
echo "   - Edit ~/.colima/default/colima.yaml"
echo "   - Add under docker section:"
echo "     docker:"
echo "       insecure-registries:"
echo "         - localhost:5000"
echo "   - Restart: colima start"
echo ""

# Try to push a test image
echo "5. Attempting to push test image..."
if docker images hello-world:latest > /dev/null 2>&1; then
    echo "   Found hello-world image"
    docker tag hello-world:latest localhost:$REGISTRY_PORT/hello-world:test
    
    if docker push localhost:$REGISTRY_PORT/hello-world:test 2>/dev/null; then
        echo "   ✅ Successfully pushed hello-world:test"
        
        # Verify the push
        echo "6. Verifying push..."
        curl -s http://localhost:$REGISTRY_PORT/v2/_catalog | jq -r '.repositories[]' 2>/dev/null || curl -s http://localhost:$REGISTRY_PORT/v2/_catalog
        
        # Try to pull it back
        echo "7. Testing pull..."
        docker rmi localhost:$REGISTRY_PORT/hello-world:test 2>/dev/null || true
        if docker pull localhost:$REGISTRY_PORT/hello-world:test 2>/dev/null; then
            echo "   ✅ Successfully pulled hello-world:test"
        else
            echo "   ⚠️  Pull failed (but push worked)"
        fi
    else
        echo "   ❌ Push failed - Docker not configured for insecure registry"
        echo ""
        echo "   💡 Manual push using curl (for testing):"
        echo "   This demonstrates the registry is working, even if Docker can't push directly."
        
        # Create a simple manifest and push via API
        echo '   Creating test manifest...'
        cat > /tmp/test-manifest.json << 'EOF'
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
   "config": {
      "mediaType": "application/vnd.docker.container.image.v1+json",
      "size": 1234,
      "digest": "sha256:abc123"
   },
   "layers": []
}
EOF
        
        if curl -X PUT -H "Content-Type: application/vnd.docker.distribution.manifest.v2+json" \
           -d @/tmp/test-manifest.json \
           "http://localhost:$REGISTRY_PORT/v2/test-image/manifests/latest" 2>/dev/null; then
            echo "   ✅ Registry API is working (test manifest uploaded)"
        else
            echo "   ⚠️  Registry API test failed"
        fi
        
        rm -f /tmp/test-manifest.json
    fi
else
    echo "   Pulling hello-world image first..."
    docker pull hello-world:latest
    echo "   Now run this script again to test pushing"
fi

echo ""
echo "8. Registry Usage Examples:"
echo "   # Tag an image for the registry"
echo "   docker tag myapp:latest localhost:$REGISTRY_PORT/myapp:v1.0"
echo ""
echo "   # Push to registry (requires insecure registry config)"
echo "   docker push localhost:$REGISTRY_PORT/myapp:v1.0"
echo ""
echo "   # Pull from registry"
echo "   docker pull localhost:$REGISTRY_PORT/myapp:v1.0"
echo ""
echo "   # List repositories"
echo "   curl http://localhost:$REGISTRY_PORT/v2/_catalog"
echo ""
echo "   # List tags for a repository"
echo "   curl http://localhost:$REGISTRY_PORT/v2/myapp/tags/list"

# Cleanup
echo ""
echo "9. Cleaning up..."
kill $PF_PID 2>/dev/null || true
echo "   Port forward stopped"

echo ""
echo "🎯 Summary:"
echo "   - Registry is running and accessible"
echo "   - Configure Docker for insecure registries to enable push/pull"
echo "   - Use the registry-helper.sh script for easier management"