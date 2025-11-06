#!/bin/bash

# Port Forward All AI Platform Infrastructure Services
# This script forwards all services to localhost for local development

set -e

NAMESPACE="ai-platform-infra"
PID_FILE="/tmp/ai-platform-port-forwards.pids"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting port forwarding for AI Platform Infrastructure${NC}"
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
    
    # Kill any kubectl port-forward processes
    pkill -f "kubectl port-forward.*$NAMESPACE" 2>/dev/null || true
    echo -e "${GREEN}✅ Cleanup complete${NC}"
    echo ""
}

# Trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Check if service exists
check_service() {
    local service=$1
    local resource_type=${2:-"svc"}
    kubectl get ${resource_type}/${service} -n $NAMESPACE > /dev/null 2>&1
}

# Start port forwarding with error handling
start_port_forward() {
    local service=$1
    local local_port=$2
    local remote_port=$3
    local resource_type=${4:-"svc"}
    local description=${5:-"$service"}
    
    if check_service "$service" "$resource_type"; then
        echo -e "${YELLOW}📡 Forwarding ${description}: localhost:${local_port} -> ${resource_type}/${service}:${remote_port}${NC}"
        kubectl port-forward -n $NAMESPACE ${resource_type}/${service} ${local_port}:${remote_port} > /dev/null 2>&1 &
        echo $! >> "$PID_FILE"
        sleep 0.5
    else
        echo -e "${RED}⚠️  Skipping ${description}: ${resource_type}/${service} not found${NC}"
    fi
}

# Clean up first
cleanup

echo -e "${BLUE}🔍 Checking available services...${NC}"
echo ""

# PostgreSQL
start_port_forward "postgresql" 5432 5432 "svc" "PostgreSQL Database"

# Redis
start_port_forward "redis" 6379 6379 "svc" "Redis Cache"

# RabbitMQ (if available)
start_port_forward "rabbitmq" 5672 5672 "svc" "RabbitMQ AMQP"
start_port_forward "rabbitmq" 15672 15672 "svc" "RabbitMQ Management UI"

# NATS
start_port_forward "nats" 4222 4222 "svc" "NATS Client"
start_port_forward "nats" 8222 8222 "svc" "NATS Monitoring"

# ClickHouse (if available)
start_port_forward "clickhouse" 8123 8123 "svc" "ClickHouse HTTP"
start_port_forward "clickhouse" 9000 9000 "svc" "ClickHouse Native"

# InfluxDB (if available)
start_port_forward "influxdb" 8086 8086 "svc" "InfluxDB"

# Qdrant
start_port_forward "qdrant" 6333 6333 "svc" "Qdrant Vector DB"

# Ray - Multiple ports
start_port_forward "ray-cluster-dev-head-svc" 10001 10001 "svc" "Ray Client"
start_port_forward "ray-cluster-dev-head-svc" 8265 8265 "svc" "Ray Dashboard"
start_port_forward "ray-cluster-dev-head-svc" 6379 6380 "svc" "Ray GCS"

# KubeRay Operator
start_port_forward "kuberay-operator" 8081 8080 "svc" "KubeRay Operator"

echo ""
echo -e "${GREEN}✅ Port forwarding setup complete!${NC}"
echo ""

# Get secrets safely
get_secret() {
    local secret_name=$1
    local key=$2
    kubectl get secret $secret_name -n $NAMESPACE -o jsonpath="{.data.$key}" 2>/dev/null | base64 -d 2>/dev/null || echo "N/A"
}

POSTGRES_USER=$(get_secret "postgresql-secret" "POSTGRES_USER")
POSTGRES_PASSWORD=$(get_secret "postgresql-secret" "POSTGRES_PASSWORD")
POSTGRES_DB=$(get_secret "postgresql-secret" "POSTGRES_DB")
REDIS_PASSWORD=$(get_secret "redis-secret" "REDIS_PASSWORD")

echo -e "${GREEN}📋 Service Access URLs:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}PostgreSQL:${NC}       localhost:5432"
echo -e "${YELLOW}Redis:${NC}            localhost:6379"
echo -e "${YELLOW}NATS:${NC}             localhost:4222 (Client), localhost:8222 (Monitoring)"
echo -e "${YELLOW}Qdrant:${NC}           localhost:6333"
echo -e "${YELLOW}Ray Client:${NC}       localhost:10001"
echo -e "${YELLOW}Ray Dashboard:${NC}    http://localhost:8265"
echo -e "${YELLOW}Ray GCS:${NC}          localhost:6380"
echo -e "${YELLOW}KubeRay Operator:${NC} localhost:8081"
echo ""
echo -e "${RED}Services not running:${NC}"
echo -e "${RED}• RabbitMQ:${NC}        localhost:5672 (AMQP), localhost:15672 (Management)"
echo -e "${RED}• ClickHouse:${NC}      localhost:8123 (HTTP), localhost:9000 (Native)"
echo -e "${RED}• InfluxDB:${NC}        localhost:8086"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}🔗 Connection Strings (Copy & Paste):${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "# PostgreSQL"
echo "export DATABASE_URL=\"postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:5432/${POSTGRES_DB}\""
echo "export POSTGRES_HOST=\"localhost\""
echo "export POSTGRES_PORT=\"5432\""
echo "export POSTGRES_USER=\"${POSTGRES_USER}\""
echo "export POSTGRES_PASSWORD=\"${POSTGRES_PASSWORD}\""
echo "export POSTGRES_DB=\"${POSTGRES_DB}\""
echo ""
echo "# Redis"
echo "export REDIS_URL=\"redis://:${REDIS_PASSWORD}@localhost:6379\""
echo "export REDIS_HOST=\"localhost\""
echo "export REDIS_PORT=\"6379\""
echo "export REDIS_PASSWORD=\"${REDIS_PASSWORD}\""
echo ""
echo "# NATS"
echo "export NATS_URL=\"nats://localhost:4222\""
echo "export NATS_HOST=\"localhost\""
echo "export NATS_PORT=\"4222\""
echo "export NATS_MONITORING_URL=\"http://localhost:8222\""
echo ""
echo "# Qdrant"
echo "export QDRANT_URL=\"http://localhost:6333\""
echo "export QDRANT_HOST=\"localhost\""
echo "export QDRANT_PORT=\"6333\""
echo ""
echo "# Ray"
echo "export RAY_ADDRESS=\"ray://localhost:10001\""
echo "export RAY_DASHBOARD_URL=\"http://localhost:8265\""
echo "export RAY_GCS_ADDRESS=\"localhost:6380\""
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}💡 Usage Tips:${NC}"
echo "  • Copy the export commands above to set environment variables"
echo "  • Ray Dashboard: http://localhost:8265 (if Ray head pod is running)"
echo "  • NATS Monitoring: http://localhost:8222"
echo "  • Press Ctrl+C to stop all port forwards"
echo "  • Port forwards run in background"
echo ""
echo -e "${BLUE}🔧 Troubleshooting:${NC}"
echo "  • If Ray Dashboard doesn't work, check: kubectl get pods -n ai-platform-infra -l ray.io/node-type=head"
echo "  • To restart Ray: kubectl delete raycluster ray-cluster-dev -n ai-platform-infra"
echo "  • Check service status: kubectl get svc -n ai-platform-infra"
echo ""
echo -e "${YELLOW}⏳ Port forwards are running. Press Ctrl+C to stop...${NC}"
echo ""

# Wait for user interrupt
wait
