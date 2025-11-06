# Port Forwarding Scripts

This directory contains scripts to easily port-forward AI Platform services to your local machine for development.

## Available Scripts

### 1. `port-forward-all.sh` - Complete Infrastructure
Forwards all configured services (running and non-running) with comprehensive connection strings.

```bash
./scripts/port-forward-all.sh
```

**Services included:**
- PostgreSQL (5432)
- Redis (6379) 
- NATS (4222, 8222)
- Qdrant (6333)
- Ray Client (10001)
- Ray Dashboard (8265)
- Ray GCS (6380)
- KubeRay Operator (8081)
- RabbitMQ (5672, 15672) - if running
- ClickHouse (8123, 9000) - if running
- InfluxDB (8086) - if running

### 2. `port-forward-essential.sh` - Currently Running Services
Forwards only the essential services that are currently running.

```bash
./scripts/port-forward-essential.sh
```

**Services included:**
- PostgreSQL (5432)
- Redis (6379)
- NATS (4222, 8222)
- Qdrant (6333)
- Ray (10001, 8265) - if available

### 3. `port-forward-ray.sh` - Ray Only
Dedicated script for Ray cluster port forwarding with detailed status checking.

```bash
./scripts/port-forward-ray.sh
```

**Ray services:**
- Ray Client API (10001)
- Ray Dashboard (8265)
- Ray GCS (6380)
- Ray Metrics (8080)

## Usage

1. **Start port forwarding:**
   ```bash
   # For all services
   ./scripts/port-forward-all.sh
   
   # For essential services only
   ./scripts/port-forward-essential.sh
   
   # For Ray only
   ./scripts/port-forward-ray.sh
   ```

2. **Copy environment variables:**
   Each script outputs connection strings you can copy and paste.

3. **Stop port forwarding:**
   Press `Ctrl+C` in the terminal running the script.

## Quick Connection Examples

### PostgreSQL
```bash
export DATABASE_URL="postgresql://postgres:postgres-dev-secret-2024@localhost:5432/ai_platform_dev"
psql $DATABASE_URL
```

### Redis
```bash
export REDIS_URL="redis://:redis-dev-secret-2024@localhost:6379"
redis-cli -h localhost -p 6379 -a redis-dev-secret-2024
```

### Ray
```python
import ray
ray.init('ray://localhost:10001')

# Or with environment variable
export RAY_ADDRESS='ray://localhost:10001'
ray.init()
```

### NATS
```bash
# Health check
curl http://localhost:8222/healthz

# Connect with NATS client
nats pub test.subject "Hello NATS" --server nats://localhost:4222
```

### Qdrant
```bash
# Check status
curl http://localhost:6333/

# Python client
from qdrant_client import QdrantClient
client = QdrantClient(host="localhost", port=6333)
```

## Troubleshooting

### Port Already in Use
If you get "port already in use" errors:
```bash
# Kill existing port forwards
pkill -f "kubectl port-forward"

# Or find and kill specific port
lsof -ti:8265 | xargs kill -9
```

### Service Not Available
If a service isn't forwarding:
```bash
# Check if service exists
kubectl get svc -n ai-platform-infra

# Check if pods are running
kubectl get pods -n ai-platform-infra

# Scale up if needed
kubectl scale deployment ai-nats -n ai-platform-infra --replicas=1
```

### Ray Issues
```bash
# Check Ray cluster status
kubectl get rayclusters -n ai-platform-infra

# Check Ray pods
kubectl get pods -n ai-platform-infra -l ray.io/cluster=ray-cluster-dev

# Restart Ray cluster
kubectl delete raycluster ray-cluster-dev -n ai-platform-infra
```

## Security Notes

- Port forwards are only accessible from localhost
- Credentials are displayed in terminal output
- Use these scripts only in development environments
- Stop port forwards when not needed to free up ports

## Background Operation

All scripts run port forwards in the background and provide a cleanup mechanism. They will:
- Clean up existing port forwards on start
- Track process IDs for proper cleanup
- Clean up on script exit (Ctrl+C)
- Show connection status and URLs