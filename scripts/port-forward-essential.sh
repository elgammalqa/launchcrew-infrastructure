#!/bin/bash

# Port Forward Essential AI Platform Services
# This script forwards only the currently running essential services

set -e

NAMESPACE="ai-platform-infra"
PID_FILE="/tmp/ai-platform-essential-port-forwards.pids"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting essential port forwarding for AI Platform${NC}"
echo ""

# Clean up existing port forwards
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up existing port forwards...${NC}"
    if [ -f "$PID_FILE" ]; then
        while read pid; do
            if ps -p $pid > /dev/null 2>&1; then
                kill $pid 2>/dev/null || true
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi
    
    # Kill any kubectl port-forward processes for essential services
    pkill -f "kubectl port-forward.*$NAMESPACE.*(postgresql|redis|nats|qdrant|ray)" 2>/dev/null || true
    echo -e "${GREEN}✅ Cleanup complete${NC}"
    echo ""
}

# Trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Start port forwarding
start_port_forward() {
    local service=$1
    local local_port=$2
    local remote_port=$3
    local resource_type=${4:-"svc"}
    local description=${5:-"$service"}
    
    echo -e "${YELLOW}📡 ${description}: localhost:${local_port} -> ${resource_type}/${service}:${remote_port}${NC}"
    kubectl port-forward -n $NAMESPACE ${resource_type}/${service} ${local_port}:${remote_port} > /dev/null 2>&1 &
    local pid=$!
    echo $pid >> "$PID_FILE"
    
    # Quick check if port forward started successfully
    sleep 1
    if ! ps -p $pid > /dev/null 2>&1; then
        echo -e "${RED}  ❌ Failed to start port forward for ${description}${NC}"
    else
        echo -e "${GREEN}  ✅ ${description} ready${NC}"
    fi
}

# Clean up first
cleanup

echo -e "${BLUE}🔍 Setting up essential services...${NC}"
echo ""

# PostgreSQL Database
start_port_forward "postgresql" 5432 5432 "svc" "PostgreSQL Database"

# Redis Cache
start_port_forward "redis" 6379 6379 "svc" "Redis Cache"

# NATS Message Broker
start_port_forward "nats" 4222 4222 "svc" "NATS Client"
start_port_forward "nats" 8222 8222 "svc" "NATS Monitoring"

# Qdrant Vector Database
start_port_forward "qdrant" 6333 6333 "svc" "Qdrant Vector DB"

# Ray (if available)
if kubectl get svc ray-cluster-dev-head-svc -n $NAMESPACE > /dev/null 2>&1; then
    start_port_forward "ray-cluster-dev-head-svc" 10001 10001 "svc" "Ray Client"
    start_port_forward "ray-cluster-dev-head-svc" 8265 8265 "svc" "Ray Dashboard"
else
    echo -e "${RED}⚠️  Ray cluster head service not found - skipping Ray port forwards${NC}"
fi

echo ""
echo -e "${GREEN}✅ Essential services port forwarding complete!${NC}"
echo ""

# Get secrets
get_secret() {
    local secret_name=$1
    local key=$2
    kubectl get secret $secret_name -n $NAMESPACE -o jsonpath="{.data.$key}" 2>/dev/null | base64 -d 2>/dev/null || echo "N/A"
}

POSTGRES_USER=$(get_secret "postgresql-secret" "POSTGRES_USER")
POSTGRES_PASSWORD=$(get_secret "postgresql-secret" "POSTGRES_PASSWORD")
POSTGRES_DB=$(get_secret "postgresql-secret" "POSTGRES_DB")
REDIS_PASSWORD=$(get_secret "redis-secret" "REDIS_PASSWORD")

echo -e "${GREEN}📋 Essential Services Access:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}PostgreSQL:${NC}       localhost:5432"
echo -e "${YELLOW}Redis:${NC}            localhost:6379"
echo -e "${YELLOW}NATS:${NC}             localhost:4222 (Client), localhost:8222 (Monitoring)"
echo -e "${YELLOW}Qdrant:${NC}           localhost:6333"
echo -e "${YELLOW}Ray Client:${NC}       localhost:10001 (if available)"
echo -e "${YELLOW}Ray Dashboard:${NC}    http://localhost:8265 (if available)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}🔗 Quick Connection Strings:${NC}"
echo ""
echo "# PostgreSQL"
echo "export DATABASE_URL=\"postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:5432/${POSTGRES_DB}\""
echo ""
echo "# Redis"
echo "export REDIS_URL=\"redis://:${REDIS_PASSWORD}@localhost:6379\""
echo ""
echo "# NATS"
echo "export NATS_URL=\"nats://localhost:4222\""
echo ""
echo "# Qdrant"
echo "export QDRANT_URL=\"http://localhost:6333\""
echo ""
echo "# Ray"
echo "export RAY_ADDRESS=\"ray://localhost:10001\""
echo ""
echo -e "${GREEN}💡 Quick Tests:${NC}"
echo "  • PostgreSQL: psql \$DATABASE_URL"
echo "  • Redis: redis-cli -h localhost -p 6379 -a \$REDIS_PASSWORD"
echo "  • NATS: curl http://localhost:8222/healthz"
echo "  • Qdrant: curl http://localhost:6333/"
echo "  • Ray Dashboard: open http://localhost:8265"
echo ""
echo -e "${YELLOW}⏳ Port forwards running. Press Ctrl+C to stop...${NC}"

# Wait for user interrupt
wait