# 🌐 NGINX Ingress Controller Setup

## ✅ Deployment Summary

### Components Deployed

1. **NGINX Ingress Controller** (namespace: `ingress-nginx`)
   - LoadBalancer Service with External IP: `192.168.5.1`
   - Controller Pod with minimal resources (100m CPU, 128Mi RAM)
   - Default backend for 404 pages
   - Metrics enabled for Prometheus

2. **AI Platform Ingress Resources** (namespace: `ai-platform-infra`)
   - RabbitMQ Management UI: `rabbitmq.local`
   - ClickHouse HTTP API: `clickhouse.local`
   - Weaviate API: `weaviate.local`
   - InfluxDB API: `influxdb.local`
   - Docker Registry: `registry.local`
   - Ray Dashboard: `ray.local`
   - PostgreSQL: `postgresql.local`

3. **Test Application** (namespace: `test-ingress`)
   - Simple nginx app: `test.local`
   - Custom HTML page with status information

## 🚀 Quick Start

### Access Services from Localhost

Since we're running on Colima/local Kubernetes, use port-forwarding:

```bash
# Start port-forward (run in background or separate terminal)
kubectl port-forward -n ingress-nginx svc/nginx-ingress-ingress-nginx-controller 8080:80

# Access services with Host header
curl -H "Host: test.local" http://localhost:8080
curl -H "Host: rabbitmq.local" http://localhost:8080
curl -H "Host: weaviate.local" http://localhost:8080/v1/meta
```

### Or use the helper script:

```bash
cd infrastructure/helm
./setup-ingress-access.sh
```

## 🌍 Browser Access

### Option 1: Add to /etc/hosts

```bash
echo '127.0.0.1 test.local rabbitmq.local clickhouse.local weaviate.local influxdb.local registry.local ray.local postgresql.local' | sudo tee -a /etc/hosts
```

Then access in browser:
- http://test.local:8080
- http://rabbitmq.local:8080
- http://weaviate.local:8080

### Option 2: Use curl with Host header

```bash
curl -H "Host: test.local" http://localhost:8080
```

## 📊 Service Endpoints

### AI Platform Services

| Service | Host | Port | Description |
|---------|------|------|-------------|
| RabbitMQ Management | rabbitmq.local | 8080 | Web UI (guest:guest) |
| ClickHouse | clickhouse.local | 8080 | HTTP API |
| Weaviate | weaviate.local | 8080 | Vector DB API |
| InfluxDB | influxdb.local | 8080 | Time Series DB UI |
| Docker Registry | registry.local | 8080 | Container Registry |
| Ray Dashboard | ray.local | 8080 | Distributed Computing UI |
| PostgreSQL | postgresql.local | 8080 | Database (TCP proxy) |

### Test Application

| Service | Host | Port | Description |
|---------|------|------|-------------|
| Test App | test.local | 8080 | Simple nginx test page |

## 🔧 Management Commands

### Check Ingress Status

```bash
# List all ingress resources
kubectl get ingress --all-namespaces

# Check ingress controller pods
kubectl get pods -n ingress-nginx

# Check ingress controller service
kubectl get svc -n ingress-nginx
```

### View Ingress Logs

```bash
# Controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Follow logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f
```

### Test Ingress Connectivity

```bash
# Test specific host
curl -H "Host: test.local" http://localhost:8080

# Test with verbose output
curl -v -H "Host: test.local" http://localhost:8080

# Test all hosts
for host in test.local rabbitmq.local clickhouse.local weaviate.local; do
  echo "Testing $host..."
  curl -s -H "Host: $host" http://localhost:8080 -o /dev/null -w "HTTP %{http_code}\n"
done
```

## 🔐 RabbitMQ Access

RabbitMQ Management UI is accessible at:
- **URL**: http://rabbitmq.local:8080 (with port-forward)
- **Username**: `guest`
- **Password**: `guest`

```bash
# Access RabbitMQ API
curl -u guest:guest -H "Host: rabbitmq.local" http://localhost:8080/api/overview
```

## 🧪 Test Application Details

The test application demonstrates:
- ✅ Ingress routing working correctly
- ✅ ConfigMap volume mounting
- ✅ Custom HTML serving
- ✅ Cross-namespace ingress support

### Test App Features:
- Beautiful gradient UI
- Real-time timestamp
- Connection details
- Access instructions

## 📝 Configuration Files

### Ingress Controller Values
- Location: `infrastructure/helm/nginx-ingress/values-dev.yaml`
- Resources: Minimal (100m CPU, 128Mi RAM)
- Type: LoadBalancer
- Class: nginx (default)

### Test Application
- Location: `infrastructure/helm/test-ingress-app.yaml`
- Includes: Deployment, Service, ConfigMap, Ingress
- Namespace: test-ingress

## 🔄 Updating Ingress Resources

### Add New Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: my-namespace
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
```

### Apply Changes

```bash
kubectl apply -f my-ingress.yaml
```

## 🐛 Troubleshooting

### Ingress Not Working

1. **Check ingress controller is running:**
   ```bash
   kubectl get pods -n ingress-nginx
   ```

2. **Check ingress resource:**
   ```bash
   kubectl describe ingress <ingress-name> -n <namespace>
   ```

3. **Check service endpoints:**
   ```bash
   kubectl get endpoints <service-name> -n <namespace>
   ```

4. **Check ingress controller logs:**
   ```bash
   kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
   ```

### 503 Service Unavailable

- Service might not be ready
- Check pod status: `kubectl get pods -n <namespace>`
- Check service: `kubectl get svc -n <namespace>`
- Verify service selector matches pod labels

### Connection Timeout

- Port-forward might not be running
- Check: `lsof -i :8080`
- Restart: `kubectl port-forward -n ingress-nginx svc/nginx-ingress-ingress-nginx-controller 8080:80`

## 🎯 Next Steps

1. **Add TLS/SSL**: Configure cert-manager for HTTPS
2. **Add Authentication**: Use oauth2-proxy or basic auth
3. **Rate Limiting**: Configure nginx rate limiting annotations
4. **Monitoring**: Set up Prometheus metrics scraping
5. **Production**: Use real domain names and DNS

## 📚 Resources

- [NGINX Ingress Controller Docs](https://kubernetes.github.io/ingress-nginx/)
- [Ingress Annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/)
- [TLS/HTTPS Setup](https://kubernetes.github.io/ingress-nginx/user-guide/tls/)

---

**Status**: ✅ **Fully Operational**

All ingress resources are deployed and accessible via port-forward on localhost:8080