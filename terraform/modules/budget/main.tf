# Budget resource commented out due to ADC quota project requirement
# To enable: Set quota project with: gcloud auth application-default set-quota-project PROJECT_ID
# resource "google_billing_budget" "budget" {
#   billing_account = var.billing_account
#   display_name    = "${var.environment}-monthly-budget"
#
#   budget_filter {
#     projects = ["projects/${var.project_id}"]
#     labels = {
#       environment = var.environment
#     }
#   }
#
#   amount {
#     specified_amount {
#       currency_code = "USD"
#       units         = tostring(var.budget_amount)
#     }
#   }
#
#   dynamic "threshold_rules" {
#     for_each = var.alert_thresholds
#     content {
#       threshold_percent = threshold_rules.value
#       spend_basis       = "CURRENT_SPEND"
#     }
#   }
#
#   all_updates_rule {
#     monitoring_notification_channels = [
#       google_monitoring_notification_channel.email_channel.id
#     ]
#     disable_default_iam_recipients = false
#   }
# }

resource "google_monitoring_notification_channel" "email_channel" {
  display_name = "${var.environment}-budget-alerts"
  type         = "email"
  project      = var.project_id

  labels = {
    email_address = var.alert_emails[0]
  }
}

# Additional email channels
resource "google_monitoring_notification_channel" "additional_email_channels" {
  count = length(var.alert_emails) > 1 ? length(var.alert_emails) - 1 : 0

  display_name = "${var.environment}-budget-alerts-${count.index + 1}"
  type         = "email"
  project      = var.project_id

  labels = {
    email_address = var.alert_emails[count.index + 1]
  }
}

# Cost alert policy - removed due to filter complexity
# Use budget alerts instead for cost monitoring
