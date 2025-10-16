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

# Cloud Build trigger for main branch (requires GitHub connection)
resource "google_cloudbuild_trigger" "main" {
  count       = var.enable_triggers ? 1 : 0
  name        = "${var.environment}-main-trigger"
  description = "Build and deploy on main branch push"
  project     = var.project_id
  location    = var.region

  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild.yaml"

  substitutions = {
    _ENVIRONMENT    = var.environment
    _CLUSTER_NAME   = var.cluster_name
    _CLUSTER_REGION = var.region
    _REGISTRY       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
  }

  service_account = google_service_account.cloudbuild.id
}

# Cloud Build trigger for dev branch
resource "google_cloudbuild_trigger" "dev" {
  count       = var.environment == "dev" && var.enable_triggers ? 1 : 0
  name        = "${var.environment}-dev-trigger"
  description = "Build and deploy on dev branch push"
  project     = var.project_id
  location    = var.region

  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      branch = "^dev$"
    }
  }

  filename = "cloudbuild.yaml"

  substitutions = {
    _ENVIRONMENT    = var.environment
    _CLUSTER_NAME   = var.cluster_name
    _CLUSTER_REGION = var.region
    _REGISTRY       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
  }

  service_account = google_service_account.cloudbuild.id
}

# Cloud Build trigger for pull requests
resource "google_cloudbuild_trigger" "pr" {
  count       = var.enable_triggers ? 1 : 0
  name        = "${var.environment}-pr-trigger"
  description = "Build and test on pull request"
  project     = var.project_id
  location    = var.region

  github {
    owner = var.github_owner
    name  = var.github_repo
    pull_request {
      branch = ".*"
    }
  }

  filename = "cloudbuild-pr.yaml"

  substitutions = {
    _ENVIRONMENT = var.environment
    _REGISTRY    = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
  }

  service_account = google_service_account.cloudbuild.id
}

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
