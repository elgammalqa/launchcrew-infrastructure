output "dashboard_id" {
  description = "Monitoring dashboard ID"
  value       = google_monitoring_dashboard.gke_dashboard.id
}

output "alert_policy_ids" {
  description = "Alert policy IDs"
  value = [
    google_monitoring_alert_policy.high_cpu.id,
    google_monitoring_alert_policy.high_memory.id,
    google_monitoring_alert_policy.pod_crashes.id
  ]
}
