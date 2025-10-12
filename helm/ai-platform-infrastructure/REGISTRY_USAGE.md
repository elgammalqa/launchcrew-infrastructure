# 🐳 Docker Registry Usage Guide

This guide shows how to use the local Docker registry deployed in your AI Platform Infrastructure.

## Quick Start

### 1. Configure Docker for Insecure Registry

The registry runs on HTTP (not HTTPS) for development, so Docker needs to be configured to allow insecure registries.

#### For Colima (Current Setup)
```bash
# Stop Colima
colima stop

# Edit configuration
vim ~/.colima/default/colima.yaml

# Add under docker section:
docker:
  insecure-registries:
    - localhost:5000
    - 127.0.0.1:5000

# Restart Colima
colima start
```

#### For Docker Desktop
1. Go to Settings > Docker Engine
2. Add to the configuration:
```json
{
  "insecure-registries": ["localhost:5000", "127.0.0.1:5000"]
}
```
3. Apply & Restart

### 2. Start Port Forwarding

```bash
# Using helper script
./registry-helper.sh start-port-forward

# Or manually
kubectl port-forward -n ai-platform-infra svc/registry 5000:5000 &
```

### 3. Test Registry Connectivity

```bash
# Test HTTP endpoint
curl http://localhost:5000/v2/

# List repositories
curl http://localhost:5000/v2/_catalog
```

## Pushing Images

### Method 1: Direct Docker Push (Recommended)

```bash
# 1. Tag your image
docker tag hello-world:latest localhost:5000/hello-world:test

# 2. Push to registry
docker push localhost:5000/hello-world:test

# 3. Verify push
curl http://localhost:5000/v2/_catalog
```

### Method 2: Using Helper Script

```bash
# Push using helper script
./registry-helper.sh push hello-world:latest

# List repositories
./registry-helper.sh list-repos
```

### Method 3: From Within Cluster

If external access is problematic, you can push from within the cluster:

```bash
# Create a temporary pod with Docker
kubectl run docker-client --rm -it --image=docker:24-dind \
  --privileged --namespace=ai-platform-infra \
  -- sh

# Inside the pod:
dockerd &
sleep 10
docker pull hello-world
docker tag hello-world registry:5000/hello-world:cluster-test
docker push registry:5000/hello-world:cluster-test
```

## Pulling Images

### From Host (with port forward)

```bash
# Pull image
docker pull localhost:5000/hello-world:test

# Run container
docker run localhost:5000/hello-world:test
```

### From Kubernetes Pods

Images can be used directly in Kubernetes without port forwarding:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: app
    image: registry:5000/hello-world:test
    # Note: using service name 'registry' and port 5000
```

## Registry Management

### List All Repositories

```bash
# Using curl
curl http://localhost:5000/v2/_catalog

# Using helper script
./registry-helper.sh list-repos
```

### List Tags for Repository

```bash
# Using curl
curl http://localhost:5000/v2/hello-world/tags/list

# Using helper script
./registry-helper.sh list-tags hello-world
```

### Delete Image (if enabled)

```bash
# Get manifest digest
DIGEST=$(curl -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  http://localhost:5000/v2/hello-world/manifests/test | \
  jq -r '.config.digest')

# Delete manifest
curl -X DELETE http://localhost:5000/v2/hello-world/manifests/$DIGEST
```

## Troubleshooting

### Connection Refused Error

```bash
# Check if registry pod is running
kubectl get pods -n ai-platform-infra | grep registry

# Check registry logs
kubectl logs -n ai-platform-infra -l component=registry

# Restart registry
kubectl rollout restart deployment -n ai-platform-infra -l component=registry
```

### Port Forward Issues

```bash
# Kill existing port forwards
pkill -f "port-forward.*registry"

# Start fresh port forward
kubectl port-forward -n ai-platform-infra svc/registry 5000:5000

# Test connectivity
curl http://localhost:5000/v2/
```

### Docker Configuration Issues

```bash
# Check Docker daemon configuration
docker info | grep -i "insecure registries" -A 5

# For Colima, check configuration
cat ~/.colima/default/colima.yaml | grep -A 5 docker
```

### Registry Not Accessible from Pods

```bash
# Test from within cluster
kubectl run test-registry --rm -it --image=curlimages/curl \
  --namespace=ai-platform-infra \
  -- curl http://registry:5000/v2/
```

## Example Workflows

### Build and Push Custom Application

```bash
# 1. Build your application
docker build -t myapp:v1.0 .

# 2. Tag for registry
docker tag myapp:v1.0 localhost:5000/myapp:v1.0

# 3. Push to registry
docker push localhost:5000/myapp:v1.0

# 4. Use in Kubernetes
kubectl run myapp --image=registry:5000/myapp:v1.0 -n ai-platform-infra
```

### CI/CD Integration

```bash
# In your CI/CD pipeline
export REGISTRY_URL="localhost:5000"

# Build
docker build -t $REGISTRY_URL/myapp:$BUILD_NUMBER .

# Push
docker push $REGISTRY_URL/myapp:$BUILD_NUMBER

# Deploy
kubectl set image deployment/myapp myapp=$REGISTRY_URL/myapp:$BUILD_NUMBER
```

## Registry Configuration

The registry is configured with:
- **Storage**: Ephemeral (emptyDir) - data lost on pod restart
- **Authentication**: None (development setup)
- **HTTPS**: Disabled (HTTP only)
- **Delete**: Enabled
- **Resources**: Minimal (64Mi memory, 25m CPU)

For production, consider:
- Persistent storage (PVC)
- Authentication (htpasswd, LDAP, etc.)
- HTTPS with proper certificates
- Backup and disaster recovery
- Resource scaling

## Helper Scripts

- `registry-helper.sh` - Main registry management script
- `test-registry.sh` - Registry testing and validation
- `get-secrets.sh` - Access registry credentials (if configured)

## Registry API Reference

The registry implements Docker Registry HTTP API V2:

- `GET /v2/` - Check API version
- `GET /v2/_catalog` - List repositories
- `GET /v2/<name>/tags/list` - List tags for repository
- `PUT /v2/<name>/manifests/<tag>` - Upload manifest
- `GET /v2/<name>/manifests/<tag>` - Download manifest
- `DELETE /v2/<name>/manifests/<digest>` - Delete manifest

For complete API documentation, see: https://docs.docker.com/registry/spec/api/