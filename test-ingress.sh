#!/bin/bash

echo "🔍 Testing Ingress and Secrets Configuration"
echo "=============================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get ingress IP
INGRESS_IP=$(kubectl get ingress rabbitmq-mgmt-ingress -n ai-platform-infra -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$INGRESS_IP" ]; then
    INGRESS_IP="192.168.106.2"
fi

echo "📡 Ingress IP: $INGRESS_IP"
echo ""

# Test 1: Check all secrets exist
echo "1️⃣  Checking Secrets..."
echo "----------------------"

secrets=("postgresql-secret" "redis-secret" "rabbitmq-secret" "clickhouse-secret" "influxdb-secret" "weaviate-secret" "registry-secret" "nats-secret")

for secret in "${secrets[@]}"; do
    if kubectl get secret $secret -n ai-platform-infra &>/dev/null; then
        echo -e "${GREEN}✅${NC} $secret exists"
    else
        echo -e "${RED}❌${NC} $secret missing"
    fi
done

echo ""

# Test 2: Verify secret values
echo "2️⃣  Verifying Secret Values..."
echo "-----------------------------"

echo -n "PostgreSQL User: "
kubectl get secret postgresql-secret -n ai-platform-infra -o jsonpath='{.data.POSTGRES_USER}' | base64 -d
echo ""

echo -n "PostgreSQL Password: "
kubectl get secret postgresql-secret -n ai-platform-infra -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
echo ""

echo -n "Redis Password: "
kubectl get secret redis-secret -n ai-platform-infra -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d
echo ""

echo -n "RabbitMQ User: "
kubectl get secret rabbitmq-secret -n ai-platform-infra -o jsonpath='{.data.RABBITMQ_DEFAULT_USER}' | base64 -d
echo ""

echo -n "RabbitMQ Password: "
kubectl get secret rabbitmq-secret -n ai-platform-infra -o jsonpath='{.data.RABBITMQ_DEFAULT_PASS}' | base64 -d
echo ""

echo ""

# Test 3: Check ingress resources
echo "3️⃣  Checking Ingress Resources..."
echo "--------------------------------"

ingresses=$(kubectl get ingress -n ai-platform-infra -o jsonpath='{.items[*].metadata.name}')

for ingress in $ingresses; do
    host=$(kubectl get ingress $ingress -n ai-platform-infra -o jsonpath='{.spec.rules[0].host}')
    if [ ! -z "$host" ]; then
        echo -e "${GREEN}✅${NC} $ingress -> $host"
    fi
done

echo ""

# Test 4: Check pods are running
echo "4️⃣  Checking Service Pods..."
echo "---------------------------"

pods=$(kubectl get pods -n ai-platform-infra --no-headers | grep -v "ray-cluster-dev-worker")

while IFS= read -r line; do
    name=$(echo $line | awk '{print $1}')
    status=$(echo $line | awk '{print $3}')
    
    if [ "$status" == "Running" ]; then
        echo -e "${GREEN}✅${NC} $name"
    elif [ "$status" == "Completed" ]; then
        echo -e "${YELLOW}⏭️${NC}  $name (completed)"
    else
        echo -e "${RED}❌${NC} $name ($status)"
    fi
done <<< "$pods"

echo ""

# Test 5: Test ingress connectivity (requires hosts file)
echo "5️⃣  Testing Ingress Connectivity..."
echo "----------------------------------"

echo -e "${YELLOW}ℹ️${NC}  Add these entries to /etc/hosts:"
echo ""
echo "$INGRESS_IP rabbitmq.local clickhouse.local weaviate.local influxdb.local registry.local"
echo ""
echo "Then test with:"
echo "  curl http://rabbitmq.local:30080"
echo "  curl http://clickhouse.local:30080/ping"
echo "  curl http://weaviate.local:30080/v1/.well-known/ready"
echo ""

# Test 6: Connection strings
echo "6️⃣  Connection Strings (from within cluster)..."
echo "-----------------------------------------------"

echo "PostgreSQL:"
kubectl get secret postgresql-secret -n ai-platform-infra -o jsonpath='{.data.DATABASE_URL}' | base64 -d
echo ""

echo ""
echo "Redis:"
kubectl get secret redis-secret -n ai-platform-infra -o jsonpath='{.data.REDIS_URL}' | base64 -d
echo ""

echo ""
echo "RabbitMQ:"
kubectl get secret rabbitmq-secret -n ai-platform-infra -o jsonpath='{.data.RABBITMQ_URL}' | base64 -d
echo ""

echo ""
echo "ClickHouse:"
kubectl get secret clickhouse-secret -n ai-platform-infra -o jsonpath='{.data.CLICKHOUSE_URL}' | base64 -d
echo ""

echo ""
echo "InfluxDB:"
kubectl get secret influxdb-secret -n ai-platform-infra -o jsonpath='{.data.INFLUXDB_URL}' | base64 -d
echo ""

echo ""
echo "Weaviate:"
kubectl get secret weaviate-secret -n ai-platform-infra -o jsonpath='{.data.WEAVIATE_URL}' | base64 -d
echo ""

echo ""
echo "✅ All tests completed!"
echo ""
echo "📝 Next Steps:"
echo "1. Add hosts entries to /etc/hosts"
echo "2. Access services via NodePort (30080 for HTTP, 30443 for HTTPS)"
echo "3. Or use port-forward for direct access"
