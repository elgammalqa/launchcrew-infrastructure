output "budget_name" {
  description = "Budget name"
  value       = "${var.environment}-monthly-budget (not created - enable manually)"
}

output "notification_channel_ids" {
  description = "Notification channel IDs"
  value = concat(
    [google_monitoring_notification_channel.email_channel.id],
    google_monitoring_notification_channel.additional_email_channels[*].id
  )
}
