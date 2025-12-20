# Load Balancer - HTTPS Load Balancer with Cloud Armor

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../modules/load-balancer"
}

dependency "api_service" {
  config_path = "../api-service"
}

inputs = {
  cloud_run_service_name = dependency.api_service.outputs.service_name

  # Domains for SSL certificate
  # Leave empty for dev to use IP-only access
  # Add your domain when ready: ["dev-api.example.com"]
  domains = []

  # Backend configuration
  backend_timeout_sec = 30

  # CDN - Disabled for dev
  enable_cdn = false

  # Logging
  enable_logging      = true
  logging_sample_rate = 1.0  # Log all requests

  # HTTP to HTTPS redirect
  enable_http_redirect = true

  # Cloud Armor WAF - Basic protection for dev
  enable_cloud_armor  = true
  enable_owasp_rules  = false  # Disable OWASP rules for dev (less strict)

  # Rate limiting - Generous limits for dev
  rate_limit_threshold        = 1000  # 1000 requests per minute
  rate_limit_interval_sec     = 60
  rate_limit_ban_duration_sec = 300

  # No country blocking for dev
  blocked_countries = []

  # Adaptive protection - Disabled for dev
  enable_adaptive_protection = false

  # Custom rules - None for dev
  custom_rules = []
}