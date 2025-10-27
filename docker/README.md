# Ray AI Platform Docker Image

This directory contains the Dockerfile and build scripts for the custom Ray image used by the AI Platform.

## Why a Custom Image?

The default Ray image has NumPy compatibility issues that prevent initialization:
- **Error**: `AttributeError: _ARRAY_API not found`
- **Cause**: NumPy 2.x incompatibility with pre-compiled packages
- **Solution**: Downgrade to NumPy 1.x and rebuild dependencies

## Building the Image

### Prerequisites

- Docker installed
- Access to container registry (GCR, ECR, or Docker Hub)
- GCP project configured (if using GCR)

### Quick Build

```bash
# Set your GCP project ID
export GCP_PROJECT="your-project-id"

# Build and test locally
docker build -f docker/ray-ai-platform.Dockerfile -t ray-ai-platform:latest .

# Test the image
docker run --rm ray-ai-platform:latest python -c "import ray; import numpy; print('✅ Success')"
```

### Build and Push

```bash
# Using the build script
cd infrastructure
./docker/build-ray-image.sh

# Or manually
export GCP_PROJECT="your-project-id"
export IMAGE_TAG="latest"

docker build -f docker/ray-ai-platform.Dockerfile \
  -t gcr.io/${GCP_PROJECT}/ray-ai-platform:${IMAGE_TAG} .

docker push gcr.io/${GCP_PROJECT}/ray-ai-platform:${IMAGE_TAG}
```

## What's Included

### Fixed Dependencies
- **NumPy**: Downgraded to <2.0 for compatibility
- **Pandas**: >=2.0.0 with compatible NumPy
- **PyArrow**: >=14.0.0 rebuilt with NumPy 1.x

### AI/ML Libraries
- OpenAI SDK
- Anthropic SDK
- LangChain and integrations
- Database clients (PostgreSQL, Redis, ClickHouse, InfluxDB)
- Message queue clients (NATS, RabbitMQ)
- Vector database client (Weaviate)

### Application Support
- PYTHONPATH set to /app
- Ready for ai_platform package installation
- All environment variables configured

## Using the Custom Image

### Update Helm Values

Edit `helm/ai-platform-infrastructure/values-dev.yaml`:

```yaml
rayCluster:
  image:
    repository: 'gcr.io/your-project-id/ray-ai-platform'
    tag: 'latest'
    pullPolicy: 'Always'
```

### Deploy

```bash
helm upgrade ai-platform-infrastructure \
  helm/ai-platform-infrastructure \
  -n ai-platform-infra \
  -f helm/ai-platform-infrastructure/values-dev.yaml
```

### Verify

```bash
# Check Ray cluster status
kubectl get raycluster -n ai-platform-infra

# Check pods
kubectl get pods -n ai-platform-infra -l ray.io/cluster=ray-cluster-dev

# Test Ray status (should not show NumPy errors)
kubectl exec -n ai-platform-infra -l ray.io/node-type=head -- ray status
```

## Adding ai_platform Package

When building from your application repository:

1. Uncomment the COPY line in the Dockerfile:
   ```dockerfile
   COPY --chown=ray:ray . /app
   ```

2. Add your package installation:
   ```dockerfile
   RUN pip install --no-cache-dir -e .
   # Or with poetry:
   # RUN poetry install --no-dev
   ```

3. Rebuild and push the image

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Build Ray Image
  run: |
    docker build -f docker/ray-ai-platform.Dockerfile \
      -t gcr.io/${{ secrets.GCP_PROJECT }}/ray-ai-platform:${{ github.sha }} \
      -t gcr.io/${{ secrets.GCP_PROJECT }}/ray-ai-platform:latest .

- name: Push Ray Image
  run: |
    docker push gcr.io/${{ secrets.GCP_PROJECT }}/ray-ai-platform:${{ github.sha }}
    docker push gcr.io/${{ secrets.GCP_PROJECT }}/ray-ai-platform:latest
```

## Troubleshooting

### NumPy Errors Still Appear

If you still see NumPy errors after using the custom image:

1. Verify the image is being used:
   ```bash
   kubectl describe pod -n ai-platform-infra -l ray.io/node-type=head | grep Image:
   ```

2. Check NumPy version inside the pod:
   ```bash
   kubectl exec -n ai-platform-infra -l ray.io/node-type=head -- python -c "import numpy; print(numpy.__version__)"
   ```

3. Rebuild the image with `--no-cache`:
   ```bash
   docker build --no-cache -f docker/ray-ai-platform.Dockerfile -t ray-ai-platform:latest .
   ```

### Image Pull Errors

If pods can't pull the image:

1. Check image exists in registry:
   ```bash
   gcloud container images list --repository=gcr.io/${GCP_PROJECT}
   ```

2. Verify cluster has pull permissions:
   ```bash
   kubectl get serviceaccount default -n ai-platform-infra -o yaml
   ```

3. Create image pull secret if needed:
   ```bash
   kubectl create secret docker-registry gcr-secret \
     --docker-server=gcr.io \
     --docker-username=_json_key \
     --docker-password="$(cat key.json)" \
     -n ai-platform-infra
   ```

## Version Compatibility

| Component | Version | Notes |
|-----------|---------|-------|
| Ray | 2.47.1 | Base image version |
| Python | 3.12.9 | From base image |
| NumPy | <2.0 | Fixed for compatibility |
| Pandas | >=2.0.0 | Compatible with NumPy 1.x |
| PyArrow | >=14.0.0 | Rebuilt with NumPy 1.x |

## References

- [Ray Documentation](https://docs.ray.io/)
- [NumPy 2.0 Migration Guide](https://numpy.org/devdocs/numpy_2_0_migration_guide.html)
- [KubeRay Setup Requirements](../docs/KUBERAY_SETUP_REQUIREMENTS.md)
