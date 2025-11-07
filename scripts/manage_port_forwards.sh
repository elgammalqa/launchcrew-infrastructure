#!/bin/bash

# Port Forward Management Script for AI Platform Infrastructure
# Usage: ./scripts/manage_port_forwards.sh [start|stop|status|restart]

set -e

NAMESPACE="ai-platform-infra"
PID_DIR="logs/port_forwards"

# Create PID directory if it doesn't exist
mkdir -p "$PID_DIR"

# Port forward configurations: service_name:local_port:remote_port:required
declare -a PORT_FORWARDS=(
    "postgresql:5432:5432:true"
    "redis:6380:6379:true"
    "nats:4222:4222:true"
    "ai-qdrant:6333:6333:true"
    "rabbitmq:15672:15672:false"
    "influxdb:8086:8086:false"
)

# Ray cluster port forwards (using pod names since service is headless)
declare -a RAY_PORT_FORWARDS=(
    "ray-dashboard:8265:8265:true"
    "ray-client:10001:10001:false"
)

# Function to check if port forward is running and healthy
check_port_forward() {
    local service=$1
    local port=$2
    local pid_file="$PID_DIR/${service}.pid"
    
    # Check if PID file exists and process is running
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            # Check if the port is actually accessible
            if timeout 3 nc -z localhost "$port" 2>/dev/null; then
                echo "✓ $service (port $port) is running and accessible (PID: $pid)"
                return 0
            else
                echo "⚠️ $service (port $port) process exists but port not accessible - cleaning up"
                kill "$pid" 2>/dev/null || true
                rm -f "$pid_file"
                return 1
            fi
        else
            echo "✗ $service (port $port) PID file exists but process is dead - cleaning up"
            rm -f "$pid_file"
            return 1
        fi
    else
        echo "✗ $service (port $port) is not running"
        return 1
    fi
}

# Function to get Ray head pod name
get_ray_head_pod() {
    kubectl get pods -n "$NAMESPACE" -l "ray.io/node-type=head" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# Function to start a single port forward
start_port_forward() {
    local service=$1
    local local_port=$2
    local remote_port=$3
    local required=$4
    local max_retries=3
    local retry=0
    local pid_file="$PID_DIR/${service}.pid"
    
    echo "Starting port forward for $service ($local_port:$remote_port)..."
    
    # Kill any existing port forward on this port
    pkill -f "kubectl port-forward.*:${local_port}" 2>/dev/null || true
    rm -f "$pid_file"
    sleep 1
    
    while [ $retry -lt $max_retries ]; do
        echo "  Attempt $((retry + 1))/$max_retries for $service..."
        
        # Start new port forward in background
        kubectl port-forward -n "$NAMESPACE" "service/$service" "$local_port:$remote_port" > /dev/null 2>&1 &
        local pid=$!
        
        # Save PID to file
        echo "$pid" > "$pid_file"
        
        # Wait for the port forward to establish
        sleep 5
        
        # Check if the process is still running and port is accessible
        if kill -0 "$pid" 2>/dev/null && timeout 5 nc -z localhost "$local_port" 2>/dev/null; then
            echo "✓ Port forward for $service started successfully (PID: $pid)"
            return 0
        else
            echo "✗ Port forward attempt $((retry + 1)) failed for $service"
            kill "$pid" 2>/dev/null || true
            rm -f "$pid_file"
            retry=$((retry + 1))
            sleep 2
        fi
    done
    
    if [ "$required" = "true" ]; then
        echo "❌ Failed to start required port forward for $service after $max_retries attempts"
        return 1
    else
        echo "⚠️ Warning: Failed to start optional port forward for $service after $max_retries attempts"
        return 0
    fi
}

# Function to start Ray port forward (uses pod instead of service)
start_ray_port_forward() {
    local service=$1
    local local_port=$2
    local remote_port=$3
    local required=$4
    local max_retries=3
    local retry=0
    local pid_file="$PID_DIR/${service}.pid"
    
    echo "Starting Ray port forward for $service ($local_port:$remote_port)..."
    
    # Get Ray head pod name
    local ray_pod=$(get_ray_head_pod)
    if [ -z "$ray_pod" ]; then
        echo "❌ No Ray head pod found"
        return 1
    fi
    
    # Kill any existing port forward on this port
    pkill -f "kubectl port-forward.*:${local_port}" 2>/dev/null || true
    rm -f "$pid_file"
    sleep 1
    
    while [ $retry -lt $max_retries ]; do
        echo "  Attempt $((retry + 1))/$max_retries for $service (pod: $ray_pod)..."
        
        # Start new port forward in background
        kubectl port-forward -n "$NAMESPACE" "$ray_pod" "$local_port:$remote_port" > /dev/null 2>&1 &
        local pid=$!
        
        # Save PID to file
        echo "$pid" > "$pid_file"
        
        # Wait for the port forward to establish
        sleep 5
        
        # Check if the process is still running and port is accessible
        if kill -0 "$pid" 2>/dev/null && timeout 5 nc -z localhost "$local_port" 2>/dev/null; then
            echo "✓ Ray port forward for $service started successfully (PID: $pid)"
            return 0
        else
            echo "✗ Ray port forward attempt $((retry + 1)) failed for $service"
            kill "$pid" 2>/dev/null || true
            rm -f "$pid_file"
            retry=$((retry + 1))
            sleep 2
        fi
    done
    
    if [ "$required" = "true" ]; then
        echo "❌ Failed to start required Ray port forward for $service after $max_retries attempts"
        return 1
    else
        echo "⚠️ Warning: Failed to start optional Ray port forward for $service after $max_retries attempts"
        return 0
    fi
}

# Function to stop a single port forward
stop_port_forward() {
    local service=$1
    local pid_file="$PID_DIR/${service}.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Stopping port forward for $service (PID: $pid)..."
            kill "$pid" 2>/dev/null || true
            sleep 1
            
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
            fi
            
            echo "✓ Stopped port forward for $service"
        fi
        rm -f "$pid_file"
    else
        echo "✓ Port forward for $service was not running"
    fi
}

# Function to check service health in Kubernetes
check_service_health() {
    local service=$1
    
    # Handle Ray services specially (they don't have dedicated services)
    if [[ "$service" == "ray-dashboard" || "$service" == "ray-client" ]]; then
        # Check if Ray head pod exists and is running
        local ray_pod=$(get_ray_head_pod)
        if [ -z "$ray_pod" ]; then
            echo "❌ No Ray head pod found in namespace $NAMESPACE"
            return 1
        fi
        
        if kubectl get pod "$ray_pod" -n "$NAMESPACE" --no-headers 2>/dev/null | grep -q "Running"; then
            echo "✓ Ray service $service has running head pod: $ray_pod"
            return 0
        else
            echo "⚠️ Ray service $service head pod is not running"
            return 1
        fi
    fi
    
    # Check if service exists
    if ! kubectl get service "$service" -n "$NAMESPACE" > /dev/null 2>&1; then
        echo "❌ Service $service does not exist in namespace $NAMESPACE"
        return 1
    fi
    
    # Check if pods are running for this service
    local label_selector=""
    case $service in
        "postgresql")
            label_selector="app=postgresql"
            ;;
        "redis")
            label_selector="app=redis"
            ;;
        "nats")
            label_selector="app=nats"
            ;;
        "ai-qdrant")
            label_selector="app.kubernetes.io/component=qdrant"
            ;;
        "rabbitmq")
            label_selector="app=rabbitmq"
            ;;
        "influxdb")
            label_selector="app=influxdb"
            ;;
        "ray-dashboard"|"ray-client")
            label_selector="ray.io/node-type=head"
            ;;
        *)
            label_selector="app=$service"
            ;;
    esac
    
    if kubectl get pods -n "$NAMESPACE" -l "$label_selector" --no-headers 2>/dev/null | grep -q "Running"; then
        echo "✓ Service $service has running pods"
        return 0
    else
        echo "⚠️ Service $service has no running pods"
        return 1
    fi
}

# Function to start all port forwards
start_all() {
    echo "🚀 Starting all port forwards for AI Platform Infrastructure..."
    echo "📍 Namespace: $NAMESPACE"
    echo ""
    
    local failed_required=0
    
    # Start regular service port forwards
    for config in "${PORT_FORWARDS[@]}"; do
        IFS=':' read -r service local_port remote_port required <<< "$config"
        
        # Check service health first
        if ! check_service_health "$service"; then
            if [ "$required" = "true" ]; then
                echo "❌ Required service $service is not healthy"
                failed_required=1
                continue
            else
                echo "⚠️ Optional service $service is not healthy, skipping"
                continue
            fi
        fi
        
        # Check if already running
        if check_port_forward "$service" "$local_port"; then
            continue
        fi
        
        # Start port forward
        if ! start_port_forward "$service" "$local_port" "$remote_port" "$required"; then
            if [ "$required" = "true" ]; then
                failed_required=1
            fi
        fi
        
        echo ""
    done
    
    # Start Ray port forwards
    for config in "${RAY_PORT_FORWARDS[@]}"; do
        IFS=':' read -r service local_port remote_port required <<< "$config"
        
        # Check if Ray head pod exists
        if ! check_service_health "$service"; then
            if [ "$required" = "true" ]; then
                echo "❌ Required Ray service $service is not healthy"
                failed_required=1
                continue
            else
                echo "⚠️ Optional Ray service $service is not healthy, skipping"
                continue
            fi
        fi
        
        # Check if already running
        if check_port_forward "$service" "$local_port"; then
            continue
        fi
        
        # Start Ray port forward
        if ! start_ray_port_forward "$service" "$local_port" "$remote_port" "$required"; then
            if [ "$required" = "true" ]; then
                failed_required=1
            fi
        fi
        
        echo ""
    done
    
    if [ $failed_required -eq 1 ]; then
        echo "❌ Some required port forwards failed to start"
        return 1
    else
        echo "✅ All port forwards started successfully"
        return 0
    fi
}

# Function to stop all port forwards
stop_all() {
    echo "🛑 Stopping all port forwards..."
    
    # Stop regular service port forwards
    for config in "${PORT_FORWARDS[@]}"; do
        IFS=':' read -r service local_port remote_port required <<< "$config"
        stop_port_forward "$service"
    done
    
    # Stop Ray port forwards
    for config in "${RAY_PORT_FORWARDS[@]}"; do
        IFS=':' read -r service local_port remote_port required <<< "$config"
        stop_port_forward "$service"
    done
    
    # Clean up any remaining kubectl port-forward processes
    echo "🧹 Cleaning up any remaining port-forward processes..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    echo "✅ All port forwards stopped"
}

# Function to show status of all port forwards
show_status() {
    echo "📊 Port Forward Status for AI Platform Infrastructure"
    echo "📍 Namespace: $NAMESPACE"
    echo ""
    
    local running=0
    local total=$((${#PORT_FORWARDS[@]} + ${#RAY_PORT_FORWARDS[@]}))
    
    echo "🔧 Infrastructure Services:"
    for config in "${PORT_FORWARDS[@]}"; do
        IFS=':' read -r service local_port remote_port required <<< "$config"
        
        local status_icon="❌"
        local status_text="Not Running"
        
        if check_port_forward "$service" "$local_port" > /dev/null 2>&1; then
            status_icon="✅"
            status_text="Running"
            running=$((running + 1))
        fi
        
        local req_text=""
        if [ "$required" = "true" ]; then
            req_text=" (Required)"
        else
            req_text=" (Optional)"
        fi
        
        printf "  %-18s %s %-15s localhost:%-5s -> %s:%-5s%s\n" \
            "$service" "$status_icon" "$status_text" "$local_port" "$service" "$remote_port" "$req_text"
    done
    
    echo ""
    echo "🚀 Ray Cluster Services:"
    for config in "${RAY_PORT_FORWARDS[@]}"; do
        IFS=':' read -r service local_port remote_port required <<< "$config"
        
        local status_icon="❌"
        local status_text="Not Running"
        
        if check_port_forward "$service" "$local_port" > /dev/null 2>&1; then
            status_icon="✅"
            status_text="Running"
            running=$((running + 1))
        fi
        
        local req_text=""
        if [ "$required" = "true" ]; then
            req_text=" (Required)"
        else
            req_text=" (Optional)"
        fi
        
        local target="ray-head-pod"
        printf "  %-18s %s %-15s localhost:%-5s -> %s:%-5s%s\n" \
            "$service" "$status_icon" "$status_text" "$local_port" "$target" "$remote_port" "$req_text"
    done
    
    echo ""
    echo "📈 Summary: $running/$total port forwards running"
    
    if [ $running -eq $total ]; then
        echo "✅ All port forwards are healthy"
        return 0
    else
        echo "⚠️ Some port forwards are not running"
        return 1
    fi
}

# Function to restart all port forwards
restart_all() {
    echo "🔄 Restarting all port forwards..."
    stop_all
    sleep 3
    start_all
}

# Function to test connectivity to all services
test_connectivity() {
    echo "🔍 Testing connectivity to all services..."
    echo ""
    
    local failed=0
    
    # Test PostgreSQL
    echo "Testing PostgreSQL connection..."
    if PGPASSWORD=postgres-dev-secret-2024 psql -h localhost -p 5432 -U postgres -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
        echo "✅ PostgreSQL connection successful"
    else
        echo "❌ PostgreSQL connection failed"
        failed=1
    fi
    
    # Test Redis
    echo "Testing Redis connection..."
    if redis-cli -h localhost -p 6380 -a redis-dev-secret-2024 ping > /dev/null 2>&1; then
        echo "✅ Redis connection successful"
    elif redis-cli -h localhost -p 6380 ping > /dev/null 2>&1; then
        echo "✅ Redis connection successful (no auth)"
    else
        echo "❌ Redis connection failed"
        failed=1
    fi
    
    # Test NATS
    echo "Testing NATS connection..."
    if python3 -c "
import asyncio
import nats
import sys

async def test_nats():
    try:
        nc = await asyncio.wait_for(
            nats.connect('nats://localhost:4222', connect_timeout=5),
            timeout=10
        )
        await nc.close()
        return True
    except:
        return False

result = asyncio.run(test_nats())
sys.exit(0 if result else 1)
" 2>/dev/null; then
        echo "✅ NATS connection successful"
    else
        echo "❌ NATS connection failed"
        failed=1
    fi
    
    # Test Qdrant
    echo "Testing Qdrant connection..."
    if curl -s http://localhost:6333 > /dev/null 2>&1; then
        echo "✅ Qdrant connection successful"
    else
        echo "❌ Qdrant connection failed"
        failed=1
    fi
    
    # Test Ray Dashboard
    echo "Testing Ray Dashboard connection..."
    if curl -s http://localhost:8265/api/gcs_healthz | grep -q "success" 2>/dev/null; then
        echo "✅ Ray Dashboard connection successful"
    else
        echo "❌ Ray Dashboard connection failed"
        failed=1
    fi
    
    echo ""
    if [ $failed -eq 0 ]; then
        echo "✅ All required services are accessible"
        return 0
    else
        echo "❌ Some required services are not accessible"
        return 1
    fi
}

# Main script logic
case "${1:-status}" in
    "start")
        start_all
        ;;
    "stop")
        stop_all
        ;;
    "status")
        show_status
        ;;
    "restart")
        restart_all
        ;;
    "test")
        test_connectivity
        ;;
    *)
        echo "Usage: $0 [start|stop|status|restart|test]"
        echo ""
        echo "Commands:"
        echo "  start    - Start all port forwards"
        echo "  stop     - Stop all port forwards"
        echo "  status   - Show status of all port forwards"
        echo "  restart  - Restart all port forwards"
        echo "  test     - Test connectivity to all services"
        echo ""
        echo "Infrastructure Services managed:"
        for config in "${PORT_FORWARDS[@]}"; do
            IFS=':' read -r service local_port remote_port required <<< "$config"
            req_text=""
            if [ "$required" = "true" ]; then
                req_text=" (Required)"
            else
                req_text=" (Optional)"
            fi
            echo "  $service - localhost:$local_port -> $service:$remote_port$req_text"
        done
        echo ""
        echo "Ray Cluster Services managed:"
        for config in "${RAY_PORT_FORWARDS[@]}"; do
            IFS=':' read -r service local_port remote_port required <<< "$config"
            req_text=""
            if [ "$required" = "true" ]; then
                req_text=" (Required)"
            else
                req_text=" (Optional)"
            fi
            echo "  $service - localhost:$local_port -> ray-head-pod:$remote_port$req_text"
        done
        exit 1
        ;;
esac