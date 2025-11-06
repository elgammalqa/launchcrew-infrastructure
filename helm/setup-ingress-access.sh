#!/bin/bash

# Setup Ingress Access Script
# This script helps configure local access to ingress services

set -e

INGRESS_IP="127.0.0.1"  # Using localhost with port-forward
INGRESS_PORT="8080"

echo "🌐 Setting up Ingress Access"
echo "================================"
echo ""

# Check if port-forward is already running
if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo "✅ Port-forward already running on port 8080"
else
    echo "🔄 Starting port-forward to NGINX Ingress Controller..."
    kubectl port-forward -n ingress-nginx svc/nginx-ingress-ingress-nginx-controller 8080:80 > /dev/null 2>&1 &
    PF_PID=$!
    echo "   Port-forward started (PID: $PF_PID)"
    sleep 3
fi

echo ""
echo "📋 Available Ingress Hosts:"
echo "================================"
echo ""

# AI Platform Services
echo "🤖 AI Platform Services (ai-platform-infra namespace):"
echo "   - RabbitMQ Management:  http://rabbitmq.local:8080"
echo "   - ClickHouse:           http://clickhouse.local:8080"
echo "   - Qdrant:               http://qdrant.local:8080"
echo "   - InfluxDB:             http://influxdb.local:8080"
echo "   - Docker Registry:      http://registry.local:8080"
echo "   - Ray Dashboard:        http://ray.local:8080"
echo ""

# Test Application
echo "🧪 Test Application (test-ingress namespace):"
echo "   - Test App:             http://test.local:8080"
echo ""

echo "================================"
echo "🔧 Usage Examples:"
echo "================================"
echo ""
echo "# Access with curl (using Host header):"
echo "curl -H 'Host: test.local' http://localhost:8080"
echo ""
echo "# Or add to /etc/hosts for browser access:"
echo "echo '127.0.0.1 test.local rabbitmq.local clickhouse.local qdrant.local influxdb.local registry.local ray.local' | sudo tee -a /etc/hosts"
echo ""
echo "# Then access in browser:"
echo "open http://test.local:8080"
echo ""

echo "================================"
echo "🧪 Testing Ingress..."
echo "================================"
echo ""

# Test the test application
echo "Testing test.local..."
RESPONSE=$(curl -s -H "Host: test.local" http://localhost:8080 --max-time 5 | grep -o "<title>.*</title>" || echo "Failed")
if [[ "$RESPONSE" == *"Test Ingress App"* ]]; then
    echo "✅ test.local is accessible"
else
    echo "❌ test.local is not accessible"
fi

echo ""
echo "Testing rabbitmq.local..."
RESPONSE=$(curl -s -H "Host: rabbitmq.local" http://localhost:8080 --max-time 5 -o /dev/null -w "%{http_code}")
if [[ "$RESPONSE" == "200" ]] || [[ "$RESPONSE" == "401" ]]; then
    echo "✅ rabbitmq.local is accessible (HTTP $RESPONSE)"
else
    echo "⚠️  rabbitmq.local returned HTTP $RESPONSE"
fi

echo ""
echo "================================"
echo "✅ Setup Complete!"
echo "================================"
echo ""
echo "💡 Tip: Keep this terminal open to maintain the port-forward"
echo "    Press Ctrl+C to stop the port-forward"
echo ""