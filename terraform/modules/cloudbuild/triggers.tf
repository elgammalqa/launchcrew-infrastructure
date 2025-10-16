# AI Agents Service Trigger
resource "google_cloudbuild_trigger" "ai_agents" {
  count       = var.enable_triggers ? 1 : 0
  name        = "ai-agents-service"
  description = "Build and deploy AI Agents Service on dev/main branch"
  project     = var.project_id
  location    = var.region

  github {
    owner = "elgammalqa"
    name  = "ai-agents-service"
    push {
      branch = "^(dev|main)$"
    }
  }

  filename = "cloudbuild.yaml"

  substitutions = {
    _SERVICE_NAME   = "ai-agents-service"
    _ENVIRONMENT    = var.environment
    _CLUSTER_NAME   = var.cluster_name
    _CLUSTER_REGION = var.region
    _REGISTRY       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
  }

  service_account = google_service_account.cloudbuild.id
}

# Auth Service Trigger
resource "google_cloudbuild_trigger" "auth" {
  count       = var.enable_triggers ? 1 : 0
  name        = "launchcrew-auth-service"
  description = "Build and deploy Auth Service on dev/main branch"
  project     = var.project_id
  location    = var.region

  github {
    owner = "elgammalqa"
    name  = "launchcrew-auth-service"
    push {
      branch = "^(dev|main)$"
    }
  }

  filename = "cloudbuild.yaml"

  substitutions = {
    _SERVICE_NAME   = "launchcrew-auth-service"
    _ENVIRONMENT    = var.environment
    _CLUSTER_NAME   = var.cluster_name
    _CLUSTER_REGION = var.region
    _REGISTRY       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
  }

  service_account = google_service_account.cloudbuild.id
}

# Billing Service Trigger
resource "google_cloudbuild_trigger" "billing" {
  count       = var.enable_triggers ? 1 : 0
  name        = "launchcrew-billing-service"
  description = "Build and deploy Billing Service on dev/main branch"
  project     = var.project_id
  location    = var.region

  github {
    owner = "elgammalqa"
    name  = "launchcrew-billing-service"
    push {
      branch = "^(dev|main)$"
    }
  }

  filename = "cloudbuild.yaml"

  substitutions = {
    _SERVICE_NAME   = "launchcrew-billing-service"
    _ENVIRONMENT    = var.environment
    _CLUSTER_NAME   = var.cluster_name
    _CLUSTER_REGION = var.region
    _REGISTRY       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
  }

  service_account = google_service_account.cloudbuild.id
}
