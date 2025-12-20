# Monitoring Module Variables

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "api_service_name" {
  description = "Name of the API Cloud Run service"
  type        = string
}

variable "api_url" {
  description = "URL of the API for uptime checks (leave empty to skip uptime check)"
  type        = string
  default     = ""
}

variable "notification_emails" {
  description = "List of email addresses for alert notifications"
  type        = list(string)
  default     = []
}

variable "enable_alerts" {
  description = "Enable alerting policies"
  type        = bool
  default     = true
}

variable "uptime_check_period" {
  description = "Uptime check period (e.g., '60s', '300s')"
  type        = string
  default     = "300s"
}

variable "health_check_path" {
  description = "Path for health check endpoint"
  type        = string
  default     = "/health"
}

variable "health_check_expected_content" {
  description = "Expected content in health check response"
  type        = string
  default     = "ok"
}

variable "error_rate_threshold" {
  description = "Alert threshold for error rate (errors per second)"
  type        = number
  default     = 5
}

variable "latency_threshold_ms" {
  description = "Alert threshold for P95 latency (milliseconds)"
  type        = number
  default     = 1000
}

variable "cloudsql_cpu_threshold" {
  description = "Alert threshold for CloudSQL CPU utilization (0.0 to 1.0)"
  type        = number
  default     = 0.8
}

variable "cloudsql_disk_threshold" {
  description = "Alert threshold for CloudSQL disk utilization (0.0 to 1.0)"
  type        = number
  default     = 0.85
}

variable "pubsub_old_message_threshold_sec" {
  description = "Alert threshold for oldest unacked Pub/Sub message age (seconds)"
  type        = number
  default     = 600
}