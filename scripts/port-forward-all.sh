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

# Start port forwarding
start_port_forward() {
    local service=$1
    local local_port=$2
    local remote_port=$3
    local resource_type=${4:-"svc"}
    
    echo -e "${YELLOW}📡 Forwarding ${resource_type}/${service}: localhost:${local_port} -> ${remote_port}${NC}"
    kubectl port-forward -n $NAMESPACE ${resource_type}/${service} ${local_port}:${remote_port} > /dev/null 2>&1 &
    echo $! >> "$PID_FILE"
    sleep 0.5
}

# Clean up first
cleanup

# PostgreSQL
start_port_forward "postgresql" 5432 5432

# Redis
start_port_forward "redis" 6379 6379

# RabbitMQ
start_port_forward "rabbitmq" 5672 5672
start_port_forward "rabbitmq" 15672 15672

# NATS
start_port_forward "nats" 4222 4222
start_port_forward "nats" 8222 8222

# ClickHouse
start_port_forward "clickhouse" 8123 8123
start_port_forward "clickhouse" 9000 9000

# InfluxDB
start_port_forward "influxdb" 8086 8086

# Weaviate
start_port_forward "weaviate" 8090 8080

# Ray Cluster Dashboard
start_port_forward "ray-cluster-dev-head-svc" 8265 8265
start_port_forward "ray-cluster-dev-head-svc" 10001 10001
start_port_forward "ray-cluster-dev-head-svc" 6380 6379

# KubeRay Operator
start_port_forward "kuberay-operator" 8081 8080

echo ""
echo -e "${GREEN}✅ All port forwards started successfully!${NC}"
echo ""

# Get secrets
POSTGRES_USER=$(kubectl get secret postgresql-secret -n $NAMESPACE -o jsonpath='{.data.POSTGRES_USER}' 2>/dev/null | base64 -d)
POSTGRES_PASSWORD=$(kubectl get secret postgresql-secret -n $NAMESPACE -o jsonpath='{.data.POSTGRES_PASSWORD}' 2>/dev/null | base64 -d)
POSTGRES_DB=$(kubectl get secret postgresql-secret -n $NAMESPACE -o jsonpath='{.data.POSTGRES_DB}' 2>/dev/null | base64 -d)
REDIS_PASSWORD=$(kubectl get secret redis-secret -n $NAMESPACE -o jsonpath='{.data.REDIS_PASSWORD}' 2>/dev/null | base64 -d)

echo -e "${GREEN}📋 Service Access URLs:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}PostgreSQL:${NC}      localhost:5432"
echo -e "${YELLOW}Redis:${NC}           localhost:6379"
echo -e "${YELLOW}RabbitMQ:${NC}        localhost:5672 (AMQP), localhost:15672 (Management UI)"
echo -e "${YELLOW}NATS:${NC}            localhost:4222 (Client), localhost:8222 (Monitoring)"
echo -e "${YELLOW}ClickHouse:${NC}      localhost:8123 (HTTP), localhost:9000 (Native)"
echo -e "${YELLOW}InfluxDB:${NC}        localhost:8086"
echo -e "${YELLOW}Weaviate:${NC}        localhost:8090"
echo -e "${YELLOW}Ray Dashboard:${NC}   localhost:8265"
echo -e "${YELLOW}Ray Client:${NC}      localhost:10001"
echo -e "${YELLOW}Ray GCS:${NC}         localhost:6380"
echo -e "${YELLOW}KubeRay Operator:${NC} localhost:8081"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}🔗 Connection Strings (Environment Variables):${NC}"
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
echo "# RabbitMQ"
echo "export RABBITMQ_URL=\"amqp://localhost:5672\""
echo "export RABBITMQ_HOST=\"localhost\""
echo "export RABBITMQ_PORT=\"5672\""
echo "export RABBITMQ_MANAGEMENT_URL=\"http://localhost:15672\""
echo ""
echo "# NATS"
echo "export NATS_URL=\"nats://localhost:4222\""
echo "export NATS_HOST=\"localhost\""
echo "export NATS_PORT=\"4222\""
echo ""
echo "# ClickHouse"
echo "export CLICKHOUSE_URL=\"http://localhost:8123\""
echo "export CLICKHOUSE_HOST=\"localhost\""
echo "export CLICKHOUSE_HTTP_PORT=\"8123\""
echo "export CLICKHOUSE_NATIVE_PORT=\"9000\""
echo ""
echo "# InfluxDB"
echo "export INFLUXDB_URL=\"http://localhost:8086\""
echo "export INFLUXDB_HOST=\"localhost\""
echo "export INFLUXDB_PORT=\"8086\""
echo ""
echo "# Weaviate"
echo "export WEAVIATE_URL=\"http://localhost:8090\""
echo "export WEAVIATE_HOST=\"localhost\""
echo "export WEAVIATE_PORT=\"8090\""
echo ""
echo "# Ray"
echo "export RAY_ADDRESS=\"ray://localhost:10001\""
echo "export RAY_DASHBOARD_URL=\"http://localhost:8265\""
echo "export RAY_GCS_ADDRESS=\"localhost:6380\""
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}💡 Tips:${NC}"
echo "  • Copy the export commands above to set environment variables"
echo "  • Press Ctrl+C to stop all port forwards"
echo "  • Port forwards run in background"
echo "  • Check connection: curl http://localhost:8265 (Ray Dashboard)"
echo ""
echo -e "${YELLOW}⏳ Port forwards are running. Press Ctrl+C to stop...${NC}"
echo ""

# Wait for user interrupt
wait
