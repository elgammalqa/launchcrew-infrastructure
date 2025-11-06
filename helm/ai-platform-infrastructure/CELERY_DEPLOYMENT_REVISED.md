# Celery Deployment Guide - Revised Configuration

This guide covers the updated Celery deployment configuration for the AI Platform Infrastructure, aligned with the K8S_CELERY_CONFIGURATION_GUIDE.md requirements.

## Overview

The Celery deployment has been revised to properly integrate with the AI multi-agent platform application. The configuration now uses the correct module paths and environment setup.

## Key Changes

### 1. Worker Configuration

**Before** (Demo setup):
```yaml
command: [/bin/sh, -c, "pip install celery redis && python /tmp/celery_app.py"]
```

**After** (Production setup):
```yaml
command:
  - celery
  - -A
  - src.core.infrastructure.queue.celery_app
  - worker
  - --loglevel=info
  - --concurrency=2
  - --queues=celery,workflows,agents
```

### 2. Image Configuration

**Update Required**: Replace the placeholder image with your actual application image:

```yaml
celery:
  worker:
    image:
      repository: 'your-registry/ai-agents'  # ← UPDATE THIS
      tag: 'latest'
```

### 3. Environment Variables

The configuration now includes:
- `REDIS_URL`: Redis connection string
- `PYTHONPATH`: Set to `/app` for proper module resolution
- `LOG_LEVEL`: Set to `INFO` for appropriate logging
- `workingDir`: Set to `/app` to ensure correct working directory

### 4. Health Checks

**Liveness Probe**: Now enabled by default
```yaml
livenessProbe:
  enabled: true
  exec:
    command: [celery, -A, src.core.infrastructure.queue.celery_app, inspect, ping]
```

**Readiness Probe**: Now enabled by default
```yaml
readinessProbe:
  enabled: true
  exec:
    command: [celery, -A, src.core.infrastructure.queue.celery_app, status]
```

### 5. Resource Allocation

Increased resources for production workloads:
```yaml
resources:
  requests:
    memory: '512Mi'
    cpu: '250m'
  limits:
    memory: '2Gi'
    cpu: '1000m'
```

## Deployment Steps

### Step 1: Update Image Reference

Edit `values-dev.yaml` and replace the image repository:

```yaml
celery:
  worker:
    image:
      repository: 'gcr.io/your-project/ai-agents'  # Your actual image
      tag: 'latest'
  beat:
    image:
      repository: 'gcr.io/your-project/ai-agents'  # Your actual image
      tag: 'latest'
```

### Step 2: Verify Application Structure

Ensure your application has the correct structure:
```
/app/
├── src/
│   └── core/
│       ├── infrastructure/
│       │   └── queue/
│       │       └── celery_app.py  ← Celery app must be here
│       └── tasks/
│           └── workflow_tasks.py  ← Your tasks
```

### Step 3: Deploy

```bash
# Deploy the updated configuration
helm upgrade ai-platform-infrastructure helm/ai-platform-infrastructure \
  --namespace ai-platform-infra \
  --values helm/ai-platform-infrastructure/values-dev.yaml \
  --set celery.worker.enabled=true \
  --set celery.beat.enabled=true \
  --set celery.flower.enabled=true
```

### Step 4: Verify Deployment

```bash
# Check pod status
kubectl get pods -n ai-platform-infra -l 'app.kubernetes.io/component in (celery-worker,celery-beat,celery-flower)'

# Check worker logs for registered tasks
kubectl logs -n ai-platform-infra -l app.kubernetes.io/component=celery-worker --tail=50
```

**Expected output in logs**:
```
[tasks]
  . src.core.tasks.workflow_tasks.execute_workflow_task
  . execute_requirements_agent_task
  . execute_ui_design_agent_task
  . execute_backend_code_agent_task
  . execute_architecture_agent_task
  . execute_deployment_agent_task

[2025-11-05 18:00:00,000: INFO/MainProcess] celery@ai-celery-worker-xxx ready.
```

## Configuration Reference

### Worker Configuration

```yaml
celery:
  worker:
    enabled: true
    replicas: 2
    image:
      repository: 'your-registry/ai-agents'
      tag: 'latest'
    command: 
      - celery
      - -A
      - src.core.infrastructure.queue.celery_app
      - worker
      - --loglevel=info
      - --concurrency=2
      - --queues=celery,workflows,agents
    workingDir: '/app'
    env:
      PYTHONPATH: '/app'
      LOG_LEVEL: 'INFO'
    resources:
      requests:
        memory: '512Mi'
        cpu: '250m'
      limits:
        memory: '2Gi'
        cpu: '1000m'
```

### Beat Configuration

```yaml
celery:
  beat:
    enabled: true
    image:
      repository: 'your-registry/ai-agents'
      tag: 'latest'
    command: 
      - celery
      - -A
      - src.core.infrastructure.queue.celery_app
      - beat
      - --loglevel=info
    workingDir: '/app'
    env:
      PYTHONPATH: '/app'
      LOG_LEVEL: 'INFO'
```

### Flower Configuration

Flower configuration remains unchanged and provides monitoring at:
- Service: `ai-celery-flower:5555`
- Access: `kubectl port-forward -n ai-platform-infra svc/ai-celery-flower 5555:5555`
- Credentials: `admin:flower-dev-secret-2024`

## Troubleshooting

### Issue: Workers not registering tasks

**Symptom**: Only `tasks.hello` appears in logs

**Solution**: 
1. Verify the image contains your application code
2. Check that `src.core.infrastructure.queue.celery_app` exists in the image
3. Verify PYTHONPATH is set to `/app`

```bash
# Test module import
kubectl exec -n ai-platform-infra <worker-pod> -- \
  python -c "from src.core.infrastructure.queue.celery_app import celery_app; print('OK')"
```

### Issue: Module import errors

**Symptom**: `ModuleNotFoundError: No module named 'src'`

**Solution**: Check working directory and PYTHONPATH

```bash
# Check working directory
kubectl exec -n ai-platform-infra <worker-pod> -- pwd

# Check PYTHONPATH
kubectl exec -n ai-platform-infra <worker-pod> -- env | grep PYTHONPATH

# List Python path
kubectl exec -n ai-platform-infra <worker-pod> -- \
  python -c "import sys; print('\n'.join(sys.path))"
```

### Issue: Workers can't connect to Redis

**Symptom**: Connection refused or timeout errors

**Solution**: Verify Redis service and credentials

```bash
# Check Redis service
kubectl get svc redis -n ai-platform-infra

# Test connection
kubectl exec -n ai-platform-infra <worker-pod> -- \
  python -c "import redis; r = redis.Redis(host='redis', port=6379, password='redis-dev-secret-2024'); print(r.ping())"
```

### Issue: Health checks failing

**Symptom**: Pods restarting frequently

**Solution**: Increase initialDelaySeconds or disable health checks temporarily

```yaml
celery:
  worker:
    livenessProbe:
      enabled: false  # Temporarily disable
```

## Testing Workflow Execution

Once deployed, test the workflow execution:

```bash
# Port forward to API
kubectl port-forward -n ai-platform-infra svc/api-service 8000:8000 &

# Create a test workflow
curl -X POST http://localhost:8000/api/v1/workflows/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_request": "Create a simple todo app", "user_preferences": {}}'

# Monitor worker logs
kubectl logs -n ai-platform-infra -l app.kubernetes.io/component=celery-worker -f
```

## Migration from Demo Setup

If you're migrating from the demo setup:

1. **Build your application image** with the Celery app and tasks
2. **Update values-dev.yaml** with the new image reference
3. **Deploy the updated configuration**
4. **Verify tasks are registered** by checking worker logs
5. **Test workflow execution** to ensure tasks are processed

## Production Considerations

For production deployment:

1. **Use specific image tags** instead of `latest`
2. **Enable autoscaling** with KEDA based on queue length
3. **Configure persistent storage** for beat schedule
4. **Set up monitoring** and alerting for worker health
5. **Use secrets** for sensitive configuration (Redis password, etc.)
6. **Configure resource limits** based on actual workload
7. **Enable network policies** to restrict traffic

## Next Steps

1. Build and push your application image with Celery tasks
2. Update the image reference in values-dev.yaml
3. Deploy the updated configuration
4. Verify tasks are registered correctly
5. Test end-to-end workflow execution
6. Monitor performance and adjust resources as needed

## Support

For issues or questions:
- Check the logs: `kubectl logs -n ai-platform-infra -l app.kubernetes.io/component=celery-worker`
- Review the configuration guide: `docs/K8S_CELERY_CONFIGURATION_GUIDE.md`
- Verify the application structure matches requirements
