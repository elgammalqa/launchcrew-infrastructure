output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "network_name" {
  description = "VPC network name"
  value       = module.vpc.network_name
}

output "budget_name" {
  description = "Budget name"
  value       = module.budget.budget_name
}

output "dashboard_id" {
  description = "Monitoring dashboard ID"
  value       = module.monitoring.dashboard_id
}

output "get_credentials_command" {
  description = "Command to get cluster credentials"
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}"
}
