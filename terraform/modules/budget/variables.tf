variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "billing_account" {
  description = "Billing account ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
}

variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
}

variable "alert_emails" {
  description = "List of email addresses for budget alerts"
  type        = list(string)
}

variable "alert_thresholds" {
  description = "Budget alert threshold percentages"
  type        = list(number)
  default     = [0.5, 0.8, 0.9, 1.0]
}
