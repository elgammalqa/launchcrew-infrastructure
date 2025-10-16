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

output "cloudbuild_service_account" {
  description = "Cloud Build service account email"
  value       = module.cloudbuild.service_account_email
}

output "artifact_registry_url" {
  description = "Artifact Registry URL"
  value       = module.cloudbuild.artifact_registry_url
}

output "build_artifacts_bucket" {
  description = "Build artifacts bucket"
  value       = module.cloudbuild.build_artifacts_bucket
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
