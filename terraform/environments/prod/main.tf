provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

locals {
  environment = "prod"
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_id   = var.project_id
  region       = var.region
  environment  = local.environment
  network_name = "${local.environment}-gke-network"
}

# GKE Module
module "gke" {
  source = "../../modules/gke"

  project_id          = var.project_id
  region              = var.region
  environment         = local.environment
  cluster_name        = "${local.environment}-gke-cluster"
  network_name        = module.vpc.network_name
  subnet_name         = module.vpc.subnet_name
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name

  node_pool_config = {
    machine_type = "e2-small" # Better for prod
    min_nodes    = 2          # HA setup
    max_nodes    = 4
    disk_size_gb = 20
    disk_type    = "pd-standard"
    preemptible  = false # Stable for prod
    spot         = false
  }

  depends_on = [module.vpc]
}

# Secrets Module
module "secrets" {
  source = "../../modules/secrets"

  project_id  = var.project_id
  region      = var.region
  environment = local.environment

  secrets = var.secrets
}

# Budget Module
module "budget" {
  source = "../../modules/budget"

  project_id      = var.project_id
  billing_account = var.billing_account
  environment     = local.environment
  budget_amount   = 200 # $200/month for prod
  alert_emails    = var.alert_emails
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"

  project_id            = var.project_id
  environment           = local.environment
  cluster_name          = module.gke.cluster_name
  notification_channels = module.budget.notification_channel_ids

  depends_on = [module.gke, module.budget]
}
