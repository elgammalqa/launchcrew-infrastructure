# Kubernetes Celery Worker Configuration Guide
## AI Multi-Agent Platform

**Date**: November 5, 2025  
**Purpose**: Fix Celery workers in Kubernetes to execute workflow tasks

---

## Problem Summary

The Celery workers in Kubernetes are **not loading the correct task modules**. They only register `tasks.hello` instead of the workflow tasks.

**Current State**:
```
[tasks]
  . tasks.hello  ❌ WRONG
```

**Required State**:
```
[tasks]
  . src.core.tasks.workflow_tasks.execute_workflow_task  ✅ CORRECT
  . execute_requirements_agent_task
  . execute_ui_design_agent_task
  . execute_backend_code_agent_task
  . execute_architecture_agent_task
  . execute_deployment_agent_task
```

---

## Root Cause

The Celery worker deployment in Kubernetes is using an incorrect startup command or missing the proper Celery app module reference.

---

## Solution: Correct Kubernetes Deployment Configuration

### 1. Check Current Configuration

```bash
kubectl get deployment ai-celery-worker -n ai-platform-infra -o yaml > current-worker-config.yaml
```

### 2. Required Deployment Configuration

Create or update the Celery worker deployment with this configuration:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-celery-worker
  namespace: ai-platform-infra
  labels:
    app: ai-celery-worker
    component: worker
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ai-celery-worker
  template:
    metadata:
      labels:
        app: ai-celery-worker
    spec:
      containers:
      - name: celery-worker
        image: <your-registry>/ai-agents:latest
        
        # CRITICAL: This is the correct command
        command:
          - celery
          - -A
          - src.core.infrastructure.queue.celery_app
          - worker
          - --loglevel=info
          - --concurrency=2
          - --queues=celery,workflows,agents
        
        env:
        # Redis connection (internal Kubernetes service)
        - name: REDIS_URL
          value: "redis://:redis-dev-secret-2024@redis:6379/0"
        
        # Or use individual components
        - name: REDIS_HOST
          value: "redis"
        - name: REDIS_PORT
          value: "6379"
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: password
        - name: REDIS_DB
          value: "0"
        
        # Database connection
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: database-url
        
        # Python path
        - name: PYTHONPATH
          value: "/app"
        
        # Working directory
        workingDir: /app
        
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        
        # Health checks
        livenessProbe:
          exec:
            command:
              - celery
              - -A
              - src.core.infrastructure.queue.celery_app
              - inspect
              - ping
          initialDelaySeconds: 30
          periodSeconds: 60
          timeoutSeconds: 10
        
        readinessProbe:
          exec:
            command:
              - celery
              - -A
              - src.core.infrastructure.queue.celery_app
              - inspect
              - active
          initialDelaySeconds: 10
          periodSeconds: 30
          timeoutSeconds: 10
```

---

## Key Configuration Points

### 1. Command (MOST IMPORTANT)

**CORRECT**:
```yaml
command:
  - celery
  - -A
  - src.core.infrastructure.queue.celery_app  # Full module path
  - worker
  - --loglevel=info
  - --concurrency=2
  - --queues=celery,workflows,agents
```

**WRONG** (Don't use these):
```yaml
# ❌ Wrong - missing module path
command: ["celery", "worker"]

# ❌ Wrong - incorrect module
command: ["celery", "-A", "tasks", "worker"]

# ❌ Wrong - incorrect module
command: ["celery", "-A", "app", "worker"]
```

### 2. Environment Variables

**Required**:
```yaml
env:
- name: REDIS_URL
  value: "redis://:password@redis:6379/0"
  
- name: DATABASE_URL
  value: "postgresql+asyncpg://user:pass@postgresql:5432/dbname"
  
- name: PYTHONPATH
  value: "/app"
```

### 3. Working Directory

```yaml
workingDir: /app
```

This ensures the Python module paths resolve correctly.

### 4. Queues

```yaml
--queues=celery,workflows,agents
```

The worker must listen to the queues where tasks are sent.

---

## Verification Steps

### 1. Apply the Configuration

```bash
kubectl apply -f celery-worker-deployment.yaml
```

### 2. Wait for Rollout

```bash
kubectl rollout status deployment/ai-celery-worker -n ai-platform-infra --timeout=5m
```

### 3. Check Pod Status

```bash
kubectl get pods -n ai-platform-infra -l app=ai-celery-worker
```

Expected output:
```
NAME                                READY   STATUS    RESTARTS   AGE
ai-celery-worker-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
ai-celery-worker-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

### 4. Check Worker Logs

```bash
kubectl logs -n ai-platform-infra -l app=ai-celery-worker --tail=50
```

**Expected output** (look for this):
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

### 5. Test Workflow Execution

```bash
# Create a test workflow
TOKEN=$(curl -s -X POST http://localhost:8001/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test-final-1760652265@launchcrew.dev","password": "TestPassword123!"}' \
  | jq -r '.data.accessToken')

WORKFLOW_RESPONSE=$(curl -s -X POST http://localhost:8000/api/v1/workflows/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_request": "Create a simple todo app", "user_preferences": {}}')

echo "$WORKFLOW_RESPONSE" | jq '{workflow_id, status, celery_task_id}'

# Wait 30 seconds
sleep 30

# Check status
WORKFLOW_ID=$(echo "$WORKFLOW_RESPONSE" | jq -r '.workflow_id')
curl -s -X GET "http://localhost:8000/api/v1/workflows/$WORKFLOW_ID" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '{status, current_node, requirements: (.requirements != null)}'
```

**Expected**: Status should progress through agents, not stuck in "running"

---

## Alternative: Using ConfigMap for Celery Config

If you want to externalize the configuration:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: celery-config
  namespace: ai-platform-infra
data:
  celery-command.sh: |
    #!/bin/bash
    set -e
    
    echo "Starting Celery worker..."
    echo "REDIS_URL: ${REDIS_URL}"
    echo "PYTHONPATH: ${PYTHONPATH}"
    
    exec celery -A src.core.infrastructure.queue.celery_app \
      worker \
      --loglevel=info \
      --concurrency=2 \
      --queues=celery,workflows,agents
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-celery-worker
  namespace: ai-platform-infra
spec:
  template:
    spec:
      containers:
      - name: celery-worker
        command: ["/bin/bash", "/config/celery-command.sh"]
        volumeMounts:
        - name: config
          mountPath: /config
      volumes:
      - name: config
        configMap:
          name: celery-config
          defaultMode: 0755
```

---

## Troubleshooting

### Issue: Workers still showing wrong tasks

**Solution**: Delete pods to force recreation
```bash
kubectl delete pods -n ai-platform-infra -l app=ai-celery-worker
```

### Issue: Workers can't connect to Redis

**Check Redis service**:
```bash
kubectl get svc redis -n ai-platform-infra
```

**Test connection from worker pod**:
```bash
kubectl exec -it -n ai-platform-infra <worker-pod-name> -- \
  redis-cli -h redis -p 6379 -a redis-dev-secret-2024 ping
```

### Issue: Module import errors

**Check PYTHONPATH**:
```bash
kubectl exec -it -n ai-platform-infra <worker-pod-name> -- \
  python -c "import sys; print('\n'.join(sys.path))"
```

**Check if module exists**:
```bash
kubectl exec -it -n ai-platform-infra <worker-pod-name> -- \
  python -c "from src.core.infrastructure.queue.celery_app import celery_app; print('OK')"
```

### Issue: Tasks not being received

**Check queue routing**:
```bash
kubectl exec -it -n ai-platform-infra <worker-pod-name> -- \
  celery -A src.core.infrastructure.queue.celery_app inspect active_queues
```

---

## Complete Example Deployment

Save this as `celery-worker-deployment.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: celery-secrets
  namespace: ai-platform-infra
type: Opaque
stringData:
  redis-password: "redis-dev-secret-2024"
  database-url: "postgresql+asyncpg://postgres:postgres-dev-secret-2024@postgresql:5432/ai_platform"

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-celery-worker
  namespace: ai-platform-infra
  labels:
    app: ai-celery-worker
    component: worker
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ai-celery-worker
  template:
    metadata:
      labels:
        app: ai-celery-worker
    spec:
      containers:
      - name: celery-worker
        image: <your-registry>/ai-agents:latest
        imagePullPolicy: Always
        
        command:
          - celery
          - -A
          - src.core.infrastructure.queue.celery_app
          - worker
          - --loglevel=info
          - --concurrency=2
          - --queues=celery,workflows,agents
        
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: celery-secrets
              key: redis-password
        - name: REDIS_URL
          value: "redis://:$(REDIS_PASSWORD)@redis:6379/0"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: celery-secrets
              key: database-url
        - name: PYTHONPATH
          value: "/app"
        - name: LOG_LEVEL
          value: "INFO"
        
        workingDir: /app
        
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        
        livenessProbe:
          exec:
            command:
              - celery
              - -A
              - src.core.infrastructure.queue.celery_app
              - inspect
              - ping
          initialDelaySeconds: 30
          periodSeconds: 60
          timeoutSeconds: 10
          failureThreshold: 3
        
        readinessProbe:
          exec:
            command:
              - celery
              - -A
              - src.core.infrastructure.queue.celery_app
              - status
          initialDelaySeconds: 10
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
      
      restartPolicy: Always
```

Apply it:
```bash
kubectl apply -f celery-worker-deployment.yaml
```

---

## Summary

### Critical Changes Needed

1. **Command**: Must use `celery -A src.core.infrastructure.queue.celery_app worker`
2. **Environment**: Must set `REDIS_URL` and `DATABASE_URL`
3. **Working Directory**: Must be `/app`
4. **Queues**: Must listen to `celery,workflows,agents`

### After Applying Changes

1. Workers will register all workflow tasks
2. Tasks will be received and executed
3. Workflows will complete successfully
4. E2E tests will pass 100%

---

**Configuration Owner**: DevOps/Platform Team  
**Priority**: CRITICAL  
**Estimated Time**: 30 minutes  
**Risk**: LOW (configuration change only)

