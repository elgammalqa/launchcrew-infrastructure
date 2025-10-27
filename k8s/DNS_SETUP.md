# DNS Configuration for flwcre.com

## LoadBalancer IP Address
```
34.172.26.53
```

## Required DNS A Records

Add these A records to your flwcre.com domain DNS:

| Hostname | Type | Value | TTL |
|----------|------|-------|-----|
| auth.flwcre.com | A | 34.172.26.53 | 300 |
| api.flwcre.com | A | 34.172.26.53 | 300 |

## Service Endpoints

After DNS propagation (5-10 minutes):

- **Auth Service**: https://auth.flwcre.com
- **Agents API**: https://api.flwcre.com

## SSL/TLS Certificates

The ingress is configured with cert-manager annotations for automatic SSL certificates:
- `cert-manager.io/cluster-issuer: "letsencrypt-prod"`

**Note**: You need to install cert-manager for automatic SSL certificates:

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer for Let's Encrypt
kubectl apply -f k8s/cert-manager-issuer.yaml
```

## Verify DNS Propagation

```bash
# Check DNS resolution
dig auth.flwcre.com +short
dig api.flwcre.com +short

# Should return: 34.172.26.53
```

## Test Endpoints

```bash
# Test auth service (HTTP - will redirect to HTTPS)
curl -v http://auth.flwcre.com

# Test agents API (HTTP - will redirect to HTTPS)
curl -v http://api.flwcre.com

# After SSL is configured:
curl https://auth.flwcre.com/health
curl https://api.flwcre.com/health
```

## Security Notes

✅ **Exposed Services:**
- auth.flwcre.com (Port 3000) - Public authentication endpoint
- api.flwcre.com (Port 8000) - Public API endpoint

❌ **NOT Exposed:**
- ai-platform-billing - Internal service only (ClusterIP)
- Billing service is only accessible within the cluster

## Current Status

- ✅ NGINX Ingress Controller installed
- ✅ LoadBalancer IP assigned: 34.172.26.53
- ✅ Ingress resources configured for flwcre.com
- ✅ Billing service ingress removed (security)
- ⏳ Waiting for DNS configuration
- ⏳ Waiting for SSL certificate setup (cert-manager)
