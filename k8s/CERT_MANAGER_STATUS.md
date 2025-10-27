# cert-manager Installation Status

## ✅ Installation Complete

**cert-manager Version**: v1.13.0
**Namespace**: cert-manager
**Status**: Running

### Installed Components
- ✅ cert-manager-cainjector
- ✅ cert-manager (controller)
- ✅ cert-manager-webhook

### ClusterIssuers Created
- ✅ letsencrypt-prod (Ready)
- ✅ letsencrypt-staging (Ready)

## SSL Certificate Status

### Auth Service (auth.flwcre.com)
- Certificate: `auth-flwcre-tls`
- Status: ⏳ Issuing (waiting for DNS validation)
- Namespace: ai-platform-auth

### Agents Service (api.flwcre.com)
- Certificate: `api-flwcre-tls`
- Status: ⏳ Issuing (waiting for DNS validation)
- Namespace: ai-platform-agents

## Important: DNS Configuration Required

**The SSL certificates will NOT be issued until DNS is configured!**

cert-manager uses HTTP-01 challenge which requires:
1. DNS records pointing to the LoadBalancer IP
2. Let's Encrypt to access http://auth.flwcre.com/.well-known/acme-challenge/
3. Let's Encrypt to access http://api.flwcre.com/.well-known/acme-challenge/

### Required DNS Records
```
auth.flwcre.com  →  34.172.26.53  (A record)
api.flwcre.com   →  34.172.26.53  (A record)
```

## Check Certificate Status

```bash
# Check certificates
kubectl get certificate -n ai-platform-auth
kubectl get certificate -n ai-platform-agents

# Check certificate details
kubectl describe certificate auth-flwcre-tls -n ai-platform-auth
kubectl describe certificate api-flwcre-tls -n ai-platform-agents

# Check challenges (during issuance)
kubectl get challenges -A

# Check certificate requests
kubectl get certificaterequest -n ai-platform-auth
kubectl get certificaterequest -n ai-platform-agents
```

## What Happens Next

1. **Configure DNS** - Add A records for auth.flwcre.com and api.flwcre.com
2. **Wait for DNS propagation** - Usually 5-10 minutes
3. **cert-manager will automatically**:
   - Create HTTP-01 challenges
   - Let's Encrypt will verify domain ownership
   - Issue SSL certificates
   - Store certificates in Kubernetes secrets
   - Certificates will auto-renew before expiration

## Troubleshooting

If certificates don't issue after DNS is configured:

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check webhook logs
kubectl logs -n cert-manager -l app=webhook

# Check challenge status
kubectl get challenges -A
kubectl describe challenge <challenge-name> -n <namespace>
```

## Manual Certificate Check (After DNS)

```bash
# Test if Let's Encrypt can reach your domain
curl -v http://auth.flwcre.com/.well-known/acme-challenge/test
curl -v http://api.flwcre.com/.well-known/acme-challenge/test
```

## Current Status Summary

✅ cert-manager installed and running
✅ ClusterIssuers configured (Let's Encrypt)
✅ Ingress resources configured with TLS
⏳ Waiting for DNS configuration
⏳ SSL certificates will be issued automatically after DNS is set
