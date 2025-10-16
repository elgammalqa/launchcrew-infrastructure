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

output "main_trigger_id" {
  description = "Main branch trigger ID"
  value       = var.enable_triggers ? google_cloudbuild_trigger.main[0].id : null
}
