# Ray RBAC Configuration

## Overview

This document describes the RBAC (Role-Based Access Control) configuration for the Ray cluster in the AI Platform infrastructure.

## Service Account

**Name:** `ray-serviceaccount`  
**Namespace:** `ai-platform-infra`

This service account is used by both Ray head and worker pods to interact with the Kubernetes API.

## Permissions

### 1. Ray Cluster Operations (ai-platform-infra namespace)

**Role:** `ray-cluster-role`  
**RoleBinding:** `ray-cluster-rolebinding`

Permissions granted:
- **Pods**: get, list, watch, create, update, patch, delete
- **Pod logs/status**: get, list
- **Services**: get, list, watch, create, update, patch, delete
- **ConfigMaps**: get, list, watch, create, update, patch, delete
- **Secrets**: get, list, watch, create, update, patch, delete
- **Events**: get, list, watch, create, update, patch
- **Deployments**: get, list, watch, create, update, patch, delete
- **ReplicaSets**: get, list, watch, create, update, patch, delete
- **Jobs**: get, list, watch, create, update, patch, delete

### 2. Preview/Deployment Functionality (preview-containers namespace)

**Role:** `ai-platform-preview-manager`  
**RoleBinding:** `ai-platform-preview-manager-binding`

Permissions granted:
- **Resource Quotas**: get, list, watch, create, update, patch
- **Pods**: get, list, watch, create, update, patch, delete
- **Services**: get, list, watch, create, update, patch, delete
- **ConfigMaps**: get, list, watch, create, update, patch, delete
- **Deployments**: get, list, watch, create, update, patch, delete

## Usage

The Ray cluster uses these permissions to:

1. **Manage Ray cluster resources**: Create and manage pods, services, and configurations for distributed computing
2. **Monitor cluster state**: Access pod logs and status for debugging and monitoring
3. **Deploy preview environments**: Create and manage resources in the preview-containers namespace for testing and deployment
4. **Resource management**: Create and manage resource quotas for preview environments

## Verification

To verify the RBAC configuration is working:

```bash
# Check service account
kubectl -n ai-platform-infra get serviceaccount ray-serviceaccount

# Check roles and rolebindings
kubectl -n ai-platform-infra get role,rolebinding | grep ray
kubectl -n preview-containers get role,rolebinding | grep ray

# Test permissions from Ray pod
kubectl -n ai-platform-infra exec ray-cluster-dev-head-<pod-id> -- python -c "
from kubernetes import client, config
config.load_incluster_config()
v1 = client.CoreV1Api()
pods = v1.list_namespaced_pod(namespace='ai-platform-infra', limit=1)
print('✅ Can access Kubernetes API')
"
```

## Security Considerations

1. **Least Privilege**: The service account only has permissions in the `ai-platform-infra` and `preview-containers` namespaces
2. **No Cluster-Wide Access**: No ClusterRole or ClusterRoleBinding is used, limiting scope to specific namespaces
3. **Namespace Isolation**: Preview environments are isolated in a separate namespace
4. **Resource Quotas**: The service account can manage resource quotas to prevent resource exhaustion

## Troubleshooting

### Permission Denied Errors

If you see permission denied errors from Ray pods:

1. Check the service account is attached to the pod:
   ```bash
   kubectl -n ai-platform-infra describe pod <ray-pod-name> | grep "Service Account"
   ```

2. Verify the role and rolebinding exist:
   ```bash
   kubectl -n ai-platform-infra get role ray-cluster-role
   kubectl -n ai-platform-infra get rolebinding ray-cluster-rolebinding
   ```

3. Check the role permissions:
   ```bash
   kubectl -n ai-platform-infra describe role ray-cluster-role
   ```

### Cross-Namespace Access Issues

If Ray cannot access the preview-containers namespace:

1. Verify the namespace exists:
   ```bash
   kubectl get namespace preview-containers
   ```

2. Check the cross-namespace rolebinding:
   ```bash
   kubectl -n preview-containers get rolebinding ai-platform-preview-manager-binding
   ```

3. Verify the subject references the correct service account:
   ```bash
   kubectl -n preview-containers describe rolebinding ai-platform-preview-manager-binding
   ```

## Related Documentation

- [Ray Cluster Configuration](./KUBERAY_SETUP_REQUIREMENTS.md)
- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Ray on Kubernetes](https://docs.ray.io/en/latest/cluster/kubernetes/index.html)
