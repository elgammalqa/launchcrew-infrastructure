# GKE Terraform Infrastructure

## Overview
Modular Terraform configuration for GKE cluster deployment optimized for cost and free tier usage.

## Structure
```
terraform/
├── environments/
│   ├── dev/
│   └── prod/
├── modules/
│   ├── vpc/
│   ├── gke/
│   ├── secrets/
│   ├── budget/
│   └── monitoring/
└── backend.tf
```

## Prerequisites
- GCP Project with billing enabled
- Terraform >= 1.5.0
- gcloud CLI configured
- GCS bucket for state (created automatically)

## Cost Optimization
- **Dev**: e2-micro nodes (free tier eligible), 1-2 nodes, preemptible
- **Prod**: e2-small nodes, 2-3 nodes, regional for HA
- Budget alerts at 50%, 80%, 100% of threshold
- Auto-scaling enabled
- Preemptible VMs for dev

## Usage

### Initialize Backend
```bash
cd environments/dev
terraform init
```

### Plan & Apply
```bash
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### Get Credentials
```bash
gcloud container clusters get-credentials <cluster-name> --region <region> --project <project-id>
```

## Budget Thresholds
- Dev: $50/month
- Prod: $200/month
