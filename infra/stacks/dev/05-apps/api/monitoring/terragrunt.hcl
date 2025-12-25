# Monitoring - Dashboards and Alerts

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../modules/monitoring"
}

dependency "api_service" {
  config_path = "../api-service"
}

dependency "load_balancer" {
  config_path = "../load-balancer"
}

inputs = {
  api_service_name = dependency.api_service.outputs.service_name

  # API URL for uptime checks
  # Use IP address for dev (no domain configured)
  api_url = "https://${dependency.load_balancer.outputs.load_balancer_ip}"

  # Notification emails - Add your email addresses here
  notification_emails = [
    # "dev-team@example.com"
  ]

  # Alerts - Disabled for dev to avoid noise
  enable_alerts = false

  # Uptime check
  uptime_check_period             = "300s"  # 5 minutes
  health_check_path               = "/health"
  health_check_expected_content   = "ok"

  # Alert thresholds - Relaxed for dev
  error_rate_threshold              = 10    # 10 errors/second
  latency_threshold_ms              = 2000  # 2 seconds
  cloudsql_cpu_threshold            = 0.9   # 90%
  cloudsql_disk_threshold           = 0.9   # 90%
  pubsub_old_message_threshold_sec  = 1200  # 20 minutes
}