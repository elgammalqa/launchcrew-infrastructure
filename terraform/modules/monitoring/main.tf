# Alert for high CPU usage
resource "google_monitoring_alert_policy" "high_cpu" {
  display_name = "${var.environment}-gke-high-cpu"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "CPU usage above 80%"
    condition_threshold {
      filter          = "resource.type = \"k8s_node\" AND resource.labels.cluster_name = \"${var.cluster_name}\" AND metric.type = \"kubernetes.io/node/cpu/allocatable_utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    auto_close = "86400s" # 24 hours
  }
}

# Alert for high memory usage
resource "google_monitoring_alert_policy" "high_memory" {
  display_name = "${var.environment}-gke-high-memory"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Memory usage above 80%"
    condition_threshold {
      filter          = "resource.type = \"k8s_node\" AND resource.labels.cluster_name = \"${var.cluster_name}\" AND metric.type = \"kubernetes.io/node/memory/allocatable_utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    auto_close = "86400s"
  }
}

# Alert for pod crashes
resource "google_monitoring_alert_policy" "pod_crashes" {
  display_name = "${var.environment}-gke-pod-crashes"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Pod restart rate high"
    condition_threshold {
      filter          = "resource.type = \"k8s_container\" AND resource.labels.cluster_name = \"${var.cluster_name}\" AND metric.type = \"kubernetes.io/container/restart_count\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.namespace_name"]
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    auto_close = "86400s"
  }
}

# Dashboard
resource "google_monitoring_dashboard" "gke_dashboard" {
  dashboard_json = jsonencode({
    displayName = "${var.environment}-gke-dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "CPU Utilization"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type = \"k8s_node\" AND resource.labels.cluster_name = \"${var.cluster_name}\" AND metric.type = \"kubernetes.io/node/cpu/allocatable_utilization\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          widget = {
            title = "Memory Utilization"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type = \"k8s_node\" AND resource.labels.cluster_name = \"${var.cluster_name}\" AND metric.type = \"kubernetes.io/node/memory/allocatable_utilization\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
              }]
            }
          }
        }
      ]
    }
  })
  project = var.project_id
}
