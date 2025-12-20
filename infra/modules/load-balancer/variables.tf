# Load Balancer Module Variables

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for regional resources"
  type        = string
  default     = "europe-west6"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service to route traffic to"
  type        = string
}

variable "domains" {
  description = "List of domains for SSL certificate (leave empty for IP-only access)"
  type        = list(string)
  default     = []
}

variable "backend_timeout_sec" {
  description = "Backend service timeout in seconds"
  type        = number
  default     = 30
}

variable "enable_cdn" {
  description = "Enable Cloud CDN"
  type        = bool
  default     = false
}

variable "cdn_default_ttl" {
  description = "Default TTL for cached content (seconds)"
  type        = number
  default     = 3600
}

variable "cdn_max_ttl" {
  description = "Maximum TTL for cached content (seconds)"
  type        = number
  default     = 86400
}

variable "cdn_client_ttl" {
  description = "Client TTL for cached content (seconds)"
  type        = number
  default     = 3600
}

variable "cdn_negative_caching" {
  description = "Enable negative caching"
  type        = bool
  default     = true
}

variable "cdn_serve_while_stale" {
  description = "Serve stale content while revalidating (seconds)"
  type        = number
  default     = 86400
}

variable "enable_logging" {
  description = "Enable request logging"
  type        = bool
  default     = true
}

variable "logging_sample_rate" {
  description = "Sample rate for request logging (0.0 to 1.0)"
  type        = number
  default     = 1.0
}

variable "enable_http_redirect" {
  description = "Enable HTTP to HTTPS redirect"
  type        = bool
  default     = true
}

variable "enable_cloud_armor" {
  description = "Enable Cloud Armor security policy"
  type        = bool
  default     = true
}

variable "enable_owasp_rules" {
  description = "Enable OWASP ModSecurity Core Rule Set"
  type        = bool
  default     = true
}

variable "rate_limit_threshold" {
  description = "Rate limit threshold (requests per interval, 0 to disable)"
  type        = number
  default     = 100
}

variable "rate_limit_interval_sec" {
  description = "Rate limit interval in seconds"
  type        = number
  default     = 60
}

variable "rate_limit_ban_duration_sec" {
  description = "Ban duration for rate limit violations (seconds)"
  type        = number
  default     = 600
}

variable "blocked_countries" {
  description = "List of country codes to block (e.g., ['CN', 'RU'])"
  type        = list(string)
  default     = []
}

variable "enable_adaptive_protection" {
  description = "Enable adaptive DDoS protection"
  type        = bool
  default     = false
}

variable "custom_rules" {
  description = "Custom Cloud Armor rules"
  type = list(object({
    priority    = number
    action      = string
    expression  = string
    description = string
  }))
  default = []
}

variable "path_matchers" {
  description = "Path-based routing configuration"
  type = map(object({
    hosts = list(string)
    path_rules = list(object({
      paths = list(string)
    }))
  }))
  default = {}
}

variable "enable_iap" {
  description = "Enable Identity-Aware Proxy"
  type        = bool
  default     = false
}

variable "iap_oauth2_client_id" {
  description = "OAuth2 client ID for IAP"
  type        = string
  default     = ""
  sensitive   = true
}

variable "iap_oauth2_client_secret" {
  description = "OAuth2 client secret for IAP"
  type        = string
  default     = ""
  sensitive   = true
}