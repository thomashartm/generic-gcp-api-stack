# Monitoring Module
# Creates dashboards, alerts, and uptime checks

# Notification channels
resource "google_monitoring_notification_channel" "email" {
  for_each = toset(var.notification_emails)

  display_name = "Email: ${each.value}"
  type         = "email"
  project      = var.project_id

  labels = {
    email_address = each.value
  }
}

# Uptime check for API endpoint
resource "google_monitoring_uptime_check_config" "api_health_check" {
  count = var.api_url != "" ? 1 : 0

  display_name = "${var.environment}-api-uptime-check"
  timeout      = "10s"
  period       = var.uptime_check_period
  project      = var.project_id

  http_check {
    path         = var.health_check_path
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = replace(var.api_url, "https://", "")
    }
  }

  content_matchers {
    content = var.health_check_expected_content
    matcher = "CONTAINS_STRING"
  }
}

# Dashboard for API metrics
resource "google_monitoring_dashboard" "api_dashboard" {
  dashboard_json = jsonencode({
    displayName = "${var.environment} API Dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "API Request Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.api_service_name}\" AND metric.type=\"run.googleapis.com/request_count\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          widget = {
            title = "API Latency (p50, p95, p99)"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.api_service_name}\" AND metric.type=\"run.googleapis.com/request_latencies\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_DELTA"
                        crossSeriesReducer = "REDUCE_PERCENTILE_50"
                      }
                    }
                  }
                  plotType = "LINE"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.api_service_name}\" AND metric.type=\"run.googleapis.com/request_latencies\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_DELTA"
                        crossSeriesReducer = "REDUCE_PERCENTILE_95"
                      }
                    }
                  }
                  plotType = "LINE"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.api_service_name}\" AND metric.type=\"run.googleapis.com/request_latencies\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_DELTA"
                        crossSeriesReducer = "REDUCE_PERCENTILE_99"
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
            }
          }
        },
        {
          width  = 6
          height = 4
          yPos   = 4
          widget = {
            title = "API Instance Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.api_service_name}\" AND metric.type=\"run.googleapis.com/container/instance_count\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MAX"
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 4
          widget = {
            title = "CloudSQL CPU Utilization"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          yPos   = 8
          widget = {
            title = "CloudSQL Memory Utilization"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/memory/utilization\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 8
          widget = {
            title = "Pub/Sub Unacked Messages"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"pubsub_subscription\" AND metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        }
      ]
    }
  })
  project = var.project_id
}

# Alert: High error rate
resource "google_monitoring_alert_policy" "high_error_rate" {
  count = var.enable_alerts ? 1 : 0

  display_name = "${var.environment} - High API Error Rate"
  combiner     = "OR"
  project      = var.project_id

  conditions {
    display_name = "Error rate above threshold"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.api_service_name}\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class!=\"2xx\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.error_rate_threshold

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [for channel in google_monitoring_notification_channel.email : channel.id]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "API error rate has exceeded ${var.error_rate_threshold} errors/second. Check Cloud Run logs for details."
    mime_type = "text/markdown"
  }
}

# Alert: High latency
resource "google_monitoring_alert_policy" "high_latency" {
  count = var.enable_alerts ? 1 : 0

  display_name = "${var.environment} - High API Latency"
  combiner     = "OR"
  project      = var.project_id

  conditions {
    display_name = "P95 latency above threshold"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.api_service_name}\" AND metric.type=\"run.googleapis.com/request_latencies\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.latency_threshold_ms

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
      }
    }
  }

  notification_channels = [for channel in google_monitoring_notification_channel.email : channel.id]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "API P95 latency has exceeded ${var.latency_threshold_ms}ms. This may indicate performance issues."
    mime_type = "text/markdown"
  }
}

# Alert: CloudSQL high CPU
resource "google_monitoring_alert_policy" "cloudsql_high_cpu" {
  count = var.enable_alerts ? 1 : 0

  display_name = "${var.environment} - CloudSQL High CPU"
  combiner     = "OR"
  project      = var.project_id

  conditions {
    display_name = "CPU utilization above threshold"

    condition_threshold {
      filter          = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloudsql_cpu_threshold

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [for channel in google_monitoring_notification_channel.email : channel.id]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "CloudSQL CPU utilization has exceeded ${var.cloudsql_cpu_threshold * 100}%. Consider scaling up the database instance."
    mime_type = "text/markdown"
  }
}

# Alert: CloudSQL high disk usage
resource "google_monitoring_alert_policy" "cloudsql_high_disk" {
  count = var.enable_alerts ? 1 : 0

  display_name = "${var.environment} - CloudSQL High Disk Usage"
  combiner     = "OR"
  project      = var.project_id

  conditions {
    display_name = "Disk utilization above threshold"

    condition_threshold {
      filter          = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/disk/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloudsql_disk_threshold

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [for channel in google_monitoring_notification_channel.email : channel.id]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "CloudSQL disk utilization has exceeded ${var.cloudsql_disk_threshold * 100}%. Consider increasing disk size."
    mime_type = "text/markdown"
  }
}

# Alert: Uptime check failure
resource "google_monitoring_alert_policy" "uptime_check_failure" {
  count = var.enable_alerts && var.api_url != "" ? 1 : 0

  display_name = "${var.environment} - API Uptime Check Failed"
  combiner     = "OR"
  project      = var.project_id

  conditions {
    display_name = "Uptime check failed"

    condition_threshold {
      filter          = "resource.type=\"uptime_url\" AND metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\""
      duration        = "60s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_FRACTION_TRUE"
      }
    }
  }

  notification_channels = [for channel in google_monitoring_notification_channel.email : channel.id]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "API uptime check has failed. The service may be down or unreachable."
    mime_type = "text/markdown"
  }
}

# Alert: Pub/Sub old unacked messages
resource "google_monitoring_alert_policy" "pubsub_old_messages" {
  count = var.enable_alerts ? 1 : 0

  display_name = "${var.environment} - Pub/Sub Old Unacked Messages"
  combiner     = "OR"
  project      = var.project_id

  conditions {
    display_name = "Messages not being processed"

    condition_threshold {
      filter          = "resource.type=\"pubsub_subscription\" AND metric.type=\"pubsub.googleapis.com/subscription/oldest_unacked_message_age\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.pubsub_old_message_threshold_sec

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }

  notification_channels = [for channel in google_monitoring_notification_channel.email : channel.id]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "Pub/Sub messages are not being processed. Oldest message is older than ${var.pubsub_old_message_threshold_sec} seconds. Check event processor service."
    mime_type = "text/markdown"
  }
}