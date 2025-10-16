output "service_account_email" {
  description = "Cloud Build service account email"
  value       = google_service_account.cloudbuild.email
}

output "artifact_registry_url" {
  description = "Artifact Registry URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}

output "build_artifacts_bucket" {
  description = "Build artifacts bucket name"
  value       = google_storage_bucket.build_artifacts.name
}

output "trigger_ids" {
  description = "Cloud Build trigger IDs"
  value = {
    ai_agents = var.enable_triggers ? google_cloudbuild_trigger.ai_agents[0].id : null
    auth      = var.enable_triggers ? google_cloudbuild_trigger.auth[0].id : null
    billing   = var.enable_triggers ? google_cloudbuild_trigger.billing[0].id : null
  }
}
