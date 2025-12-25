# Networking Module Variables

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
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

variable "vpc_connector_cidr" {
  description = "CIDR range for the VPC Access Connector (must be /28)"
  type        = string
  default     = "10.8.0.0/28"

  validation {
    condition     = can(regex("/28$", var.vpc_connector_cidr))
    error_message = "VPC connector CIDR must be a /28 range."
  }
}

variable "vpc_connector_min_instances" {
  description = "Minimum number of VPC connector instances"
  type        = number
  default     = 2
}

variable "vpc_connector_max_instances" {
  description = "Maximum number of VPC connector instances"
  type        = number
  default     = 3
}