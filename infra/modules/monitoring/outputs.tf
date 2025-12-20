# Monitoring Module Outputs

output "dashboard_id" {
  description = "ID of the API dashboard"
  value       = google_monitoring_dashboard.api_dashboard.id
}

output "uptime_check_id" {
  description = "ID of the uptime check (empty if no API URL provided)"
  value       = length(google_monitoring_uptime_check_config.api_health_check) > 0 ? google_monitoring_uptime_check_config.api_health_check[0].id : ""
}

output "notification_channel_ids" {
  description = "Map of email addresses to notification channel IDs"
  value       = { for email, channel in google_monitoring_notification_channel.email : email => channel.id }
}

output "alert_policy_ids" {
  description = "Map of alert policy names to IDs"
  value = merge(
    var.enable_alerts ? {
      high_error_rate   = google_monitoring_alert_policy.high_error_rate[0].id
      high_latency      = google_monitoring_alert_policy.high_latency[0].id
      cloudsql_high_cpu = google_monitoring_alert_policy.cloudsql_high_cpu[0].id
      cloudsql_high_disk = google_monitoring_alert_policy.cloudsql_high_disk[0].id
      pubsub_old_messages = google_monitoring_alert_policy.pubsub_old_messages[0].id
    } : {},
    var.enable_alerts && var.api_url != "" ? {
      uptime_check_failure = google_monitoring_alert_policy.uptime_check_failure[0].id
    } : {}
  )
}