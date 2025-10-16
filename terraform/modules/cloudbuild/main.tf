# Cloud Build Service Account
resource "google_service_account" "cloudbuild" {
  account_id   = "cloudbuild-sa-${var.environment}"
  display_name = "Cloud Build Service Account - ${var.environment}"
  project      = var.project_id
}

# IAM roles for Cloud Build SA
resource "google_project_iam_member" "cloudbuild_roles" {
  for_each = toset([
    "roles/container.developer",
    "roles/storage.admin",
    "roles/artifactregistry.writer",
    "roles/logging.logWriter",
    "roles/cloudbuild.builds.builder",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# Artifact Registry for Docker images
resource "google_artifact_registry_repository" "docker" {
  location      = var.region
  repository_id = "${var.environment}-docker-repo"
  description   = "Docker repository for ${var.environment}"
  format        = "DOCKER"
  project       = var.project_id

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Infrastructure repo triggers moved to triggers.tf

# Storage bucket for build artifacts
resource "google_storage_bucket" "build_artifacts" {
  name          = "${var.project_id}-${var.environment}-build-artifacts"
  location      = var.region
  project       = var.project_id
  force_destroy = var.environment == "dev"

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# IAM for build artifacts bucket
resource "google_storage_bucket_iam_member" "cloudbuild_artifacts" {
  bucket = google_storage_bucket.build_artifacts.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.cloudbuild.email}"
}
