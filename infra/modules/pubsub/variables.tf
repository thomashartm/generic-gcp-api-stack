# Pub/Sub Module Variables

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for Cloud Run services"
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

variable "event_processor_url" {
  description = "URL of the Event Processor Cloud Run service"
  type        = string
  default     = ""
}

variable "event_processor_service_name" {
  description = "Name of the Event Processor Cloud Run service"
  type        = string
  default     = ""
}

variable "event_processor_service_account" {
  description = "Service account email for the Event Processor"
  type        = string
}

variable "publisher_service_accounts" {
  description = "List of service accounts that can publish to the topic (format: serviceAccount:email@project.iam.gserviceaccount.com)"
  type        = list(string)
  default     = []
}

variable "message_retention_duration" {
  description = "Message retention duration for the main topic"
  type        = string
  default     = "86400s"  # 24 hours
}

variable "dead_letter_retention_duration" {
  description = "Message retention duration for the dead letter topic"
  type        = string
  default     = "604800s"  # 7 days
}

variable "subscription_message_retention" {
  description = "Message retention duration for the subscription"
  type        = string
  default     = "604800s"  # 7 days
}

variable "ack_deadline_seconds" {
  description = "Acknowledgement deadline in seconds"
  type        = number
  default     = 60
}

variable "max_delivery_attempts" {
  description = "Maximum delivery attempts before sending to dead letter topic"
  type        = number
  default     = 5
}

variable "retry_minimum_backoff" {
  description = "Minimum backoff for retry policy"
  type        = string
  default     = "10s"
}

variable "retry_maximum_backoff" {
  description = "Maximum backoff for retry policy"
  type        = string
  default     = "600s"  # 10 minutes
}