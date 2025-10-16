provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

locals {
  environment = "dev"
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
    machine_type = "e2-standard-4"
    min_nodes    = 0
    max_nodes    = 2
    disk_size_gb = 30
    disk_type    = "pd-standard"
    preemptible  = false
    spot         = true
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
  budget_amount   = 50 # $50/month for dev
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
