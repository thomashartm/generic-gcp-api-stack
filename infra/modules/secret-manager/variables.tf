# Secret Manager Module Variables

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

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_user" {
  description = "Database username"
  type        = string
  default     = "appuser"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "appdb"
}

variable "additional_secrets" {
  description = "Map of additional secret names to secret values"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "accessor_service_accounts" {
  description = "List of service accounts that can access the secrets (format: serviceAccount:email@project.iam.gserviceaccount.com)"
  type        = list(string)
  default     = []
}