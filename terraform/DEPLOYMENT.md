# GKE Terraform Deployment Guide

## Prerequisites

1. **GCP Account** with billing enabled
2. **gcloud CLI** installed and configured
3. **Terraform** >= 1.5.0 installed
4. **Required APIs** enabled:
   ```bash
   gcloud services enable container.googleapis.com
   gcloud services enable compute.googleapis.com
   gcloud services enable servicenetworking.googleapis.com
   gcloud services enable cloudresourcemanager.googleapis.com
   gcloud services enable secretmanager.googleapis.com
   gcloud services enable monitoring.googleapis.com
   gcloud services enable cloudbilling.googleapis.com
   ```

## Step 1: Setup Backend Storage

Create GCS bucket for Terraform state:

```bash
cd scripts
chmod +x setup-backend.sh
./setup-backend.sh YOUR_PROJECT_ID dev
./setup-backend.sh YOUR_PROJECT_ID prod
```

Update `backend.tf` in each environment with your bucket name.

## Step 2: Configure Variables

Copy and edit the tfvars file:

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

Required variables:
- `project_id`: Your GCP project ID
- `billing_account`: Your billing account ID (find with `gcloud billing accounts list`)
- `alert_emails`: Email addresses for alerts
- `region`: GCP region (default: us-central1)

## Step 3: Deploy Dev Environment

```bash
# Using Makefile
make init-dev
make plan-dev
make apply-dev

# Or using script
cd scripts
chmod +x deploy.sh
./deploy.sh dev apply
```

## Step 4: Get Cluster Credentials

```bash
gcloud container clusters get-credentials dev-gke-cluster \
  --region us-central1 \
  --project YOUR_PROJECT_ID

# Verify
kubectl get nodes
```

## Step 5: Deploy Prod Environment

```bash
make init-prod
make plan-prod
make apply-prod
```

## Cost Optimization Features

### Dev Environment
- **e2-micro** instances (free tier eligible)
- **Preemptible VMs** (80% cost savings)
- **1-2 nodes** with autoscaling
- **10GB disks** (minimum)
- **Budget**: $50/month with alerts at 50%, 80%, 90%, 100%

### Prod Environment
- **e2-small** instances (cost-effective)
- **Standard VMs** (reliability)
- **2-4 nodes** with autoscaling
- **20GB disks**
- **Budget**: $200/month with alerts

## Monitoring & Alerts

Automatically configured:
- CPU usage > 80%
- Memory usage > 80%
- Pod restart rate high
- Budget threshold alerts
- Custom dashboard in Cloud Monitoring

## Cleanup

```bash
# Dev
make destroy-dev

# Prod
make destroy-prod
```

## Estimated Costs

Run cost estimates:
```bash
make cost-estimate-dev
make cost-estimate-prod
```

## Troubleshooting

### Backend initialization fails
Ensure GCS bucket exists and you have permissions.

### API not enabled
Run the API enable commands from prerequisites.

### Budget alerts not working
Verify billing account ID is correct.

### Node pool creation fails
Check quotas: `gcloud compute project-info describe --project=YOUR_PROJECT_ID`

## Best Practices Applied

✓ Private GKE cluster with Cloud NAT
✓ Workload Identity enabled
✓ Network policies enabled
✓ Auto-repair and auto-upgrade
✓ Shielded nodes
✓ Minimal node permissions
✓ Budget alerts and monitoring
✓ Cost-optimized machine types
✓ Preemptible nodes for dev
✓ Regional deployment for prod HA
