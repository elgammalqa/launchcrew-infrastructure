#!/bin/bash

# Test Ray Connection via port 10001

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🧪 Testing Ray connection on localhost:10001${NC}"
echo ""

# Check if port forward is running
if ! nc -z localhost 10001 2>/dev/null; then
    echo -e "${RED}❌ Port 10001 is not accessible${NC}"
    echo -e "${YELLOW}💡 Run: kubectl port-forward -n ai-platform-infra svc/ray-cluster-dev-head-svc 10001:10001${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Port 10001 is accessible${NC}"
echo ""

# Test with kubectl exec
echo -e "${YELLOW}📊 Ray Cluster Status:${NC}"
POD_NAME=$(kubectl get pods -n ai-platform-infra -l ray.io/node-type=head -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n ai-platform-infra $POD_NAME -- ray status

echo ""
echo -e "${GREEN}✅ Ray cluster is healthy and accessible!${NC}"
echo ""
echo -e "${YELLOW}📋 Connection Details:${NC}"
echo "  • Ray Address: ray://localhost:10001"
echo "  • Dashboard: http://localhost:8265 (if port-forwarded)"
echo "  • GCS: localhost:6379"
echo ""
echo -e "${YELLOW}💡 To connect from Python:${NC}"
echo "  import ray"
echo "  ray.init('ray://localhost:10001')"
echo ""
