# Artifact Registry Module Variables

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the repository"
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

variable "repository_id" {
  description = "ID of the Artifact Registry repository"
  type        = string
  default     = "api"
}

variable "reader_service_accounts" {
  description = "List of service accounts that can pull images (format: serviceAccount:email@project.iam.gserviceaccount.com)"
  type        = list(string)
  default     = []
}

variable "writer_members" {
  description = "List of members (users, service accounts, groups) that can push images"
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Additional labels to apply to the repository"
  type        = map(string)
  default     = {}
}