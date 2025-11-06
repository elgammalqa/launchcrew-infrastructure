#!/bin/bash

# Port Forward Ray Services Only
# This script forwards Ray cluster services for AI development

set -e

NAMESPACE="ai-platform-infra"
PID_FILE="/tmp/ray-port-forwards.pids"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting Ray port forwarding${NC}"
echo ""

# Clean up existing port forwards
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up Ray port forwards...${NC}"
    if [ -f "$PID_FILE" ]; then
        while read pid; do
            if ps -p $pid > /dev/null 2>&1; then
                kill $pid 2>/dev/null || true
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi
    
    # Kill any kubectl port-forward processes for Ray
    pkill -f "kubectl port-forward.*ray.*$NAMESPACE" 2>/dev/null || true
    echo -e "${GREEN}✅ Cleanup complete${NC}"
    echo ""
}

# Trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Check Ray cluster status
echo -e "${BLUE}🔍 Checking Ray cluster status...${NC}"
if ! kubectl get raycluster ray-cluster-dev -n $NAMESPACE > /dev/null 2>&1; then
    echo -e "${RED}❌ Ray cluster 'ray-cluster-dev' not found in namespace '$NAMESPACE'${NC}"
    exit 1
fi

RAY_STATUS=$(kubectl get raycluster ray-cluster-dev -n $NAMESPACE -o jsonpath='{.status.state}' 2>/dev/null || echo "unknown")
echo -e "${YELLOW}Ray Cluster Status: ${RAY_STATUS}${NC}"

# Check for Ray head service
if ! kubectl get svc ray-cluster-dev-head-svc -n $NAMESPACE > /dev/null 2>&1; then
    echo -e "${RED}❌ Ray head service not found. Ray cluster may not be ready.${NC}"
    echo -e "${YELLOW}💡 Try: kubectl get pods -n $NAMESPACE -l ray.io/cluster=ray-cluster-dev${NC}"
    exit 1
fi

# Clean up first
cleanup

echo -e "${BLUE}📡 Setting up Ray port forwards...${NC}"
echo ""

# Start port forwarding
start_ray_port_forward() {
    local local_port=$1
    local remote_port=$2
    local description=$3
    
    echo -e "${YELLOW}📡 ${description}: localhost:${local_port} -> ray-cluster-dev-head-svc:${remote_port}${NC}"
    kubectl port-forward -n $NAMESPACE svc/ray-cluster-dev-head-svc ${local_port}:${remote_port} > /dev/null 2>&1 &
    local pid=$!
    echo $pid >> "$PID_FILE"
    
    # Quick check if port forward started successfully
    sleep 1
    if ! ps -p $pid > /dev/null 2>&1; then
        echo -e "${RED}  ❌ Failed to start ${description}${NC}"
    else
        echo -e "${GREEN}  ✅ ${description} ready${NC}"
    fi
}

# Ray Client Port (for ray.init())
start_ray_port_forward 10001 10001 "Ray Client API"

# Ray Dashboard (Web UI)
start_ray_port_forward 8265 8265 "Ray Dashboard"

# Ray GCS (Global Control Store)
start_ray_port_forward 6380 6379 "Ray GCS"

# Ray Metrics (Prometheus)
start_ray_port_forward 8080 8080 "Ray Metrics"

echo ""
echo -e "${GREEN}✅ Ray port forwarding complete!${NC}"
echo ""
echo -e "${GREEN}📋 Ray Access URLs:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}Ray Client:${NC}       ray://localhost:10001"
echo -e "${YELLOW}Ray Dashboard:${NC}    http://localhost:8265"
echo -e "${YELLOW}Ray GCS:${NC}          localhost:6380"
echo -e "${YELLOW}Ray Metrics:${NC}      http://localhost:8080/metrics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}🐍 Python Usage:${NC}"
echo ""
echo "import ray"
echo "ray.init('ray://localhost:10001')"
echo ""
echo "# Or set environment variable:"
echo "export RAY_ADDRESS='ray://localhost:10001'"
echo "ray.init()  # Will use RAY_ADDRESS automatically"
echo ""
echo -e "${GREEN}💡 Quick Tests:${NC}"
echo "  • Dashboard: open http://localhost:8265"
echo "  • Health: curl http://localhost:8265/api/gcs_healthz"
echo "  • Cluster info: curl http://localhost:8265/api/cluster_status"
echo ""
echo -e "${BLUE}🔧 Troubleshooting:${NC}"
echo "  • Check Ray pods: kubectl get pods -n $NAMESPACE -l ray.io/cluster=ray-cluster-dev"
echo "  • Ray logs: kubectl logs -n $NAMESPACE -l ray.io/node-type=head"
echo "  • Restart cluster: kubectl delete raycluster ray-cluster-dev -n $NAMESPACE"
echo ""
echo -e "${YELLOW}⏳ Ray port forwards running. Press Ctrl+C to stop...${NC}"

# Wait for user interrupt
wait