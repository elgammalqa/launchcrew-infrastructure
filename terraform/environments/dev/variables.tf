variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "billing_account" {
  description = "Billing account ID"
  type        = string
}

variable "alert_emails" {
  description = "List of email addresses for alerts"
  type        = list(string)
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "elgammalqa"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "launchcrew-services"
}

variable "secrets" {
  description = "Map of secrets to create"
  type = map(object({
    secret_data = string
    labels      = map(string)
  }))
  default = {}
}
