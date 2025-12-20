# Cloud Run Module Variables

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud Run service"
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

variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
}

variable "image_url" {
  description = "Container image URL (e.g., europe-west6-docker.pkg.dev/project/repo/image:tag)"
  type        = string
}

variable "service_account_email" {
  description = "Email of the service account to use for the Cloud Run service"
  type        = string
}

variable "vpc_connector_id" {
  description = "ID of the VPC Access Connector"
  type        = string
}

variable "vpc_egress" {
  description = "VPC egress setting (ALL_TRAFFIC or PRIVATE_RANGES_ONLY)"
  type        = string
  default     = "PRIVATE_RANGES_ONLY"

  validation {
    condition     = contains(["ALL_TRAFFIC", "PRIVATE_RANGES_ONLY"], var.vpc_egress)
    error_message = "VPC egress must be ALL_TRAFFIC or PRIVATE_RANGES_ONLY."
  }
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 10
}

variable "cpu_limit" {
  description = "CPU limit (e.g., '1', '2', '4')"
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit (e.g., '512Mi', '1Gi', '2Gi')"
  type        = string
  default     = "512Mi"
}

variable "cpu_always_allocated" {
  description = "Always allocate CPU (true) or only during request processing (false)"
  type        = bool
  default     = false
}

variable "startup_cpu_boost" {
  description = "Enable startup CPU boost"
  type        = bool
  default     = true
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3000
}

variable "env_vars" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secret environment variables (map of env var name to secret config)"
  type = map(object({
    secret_name = string
    version     = string
  }))
  default = {}
}

variable "ingress" {
  description = "Ingress traffic setting"
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"

  validation {
    condition = contains([
      "INGRESS_TRAFFIC_ALL",
      "INGRESS_TRAFFIC_INTERNAL_ONLY",
      "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
    ], var.ingress)
    error_message = "Ingress must be one of: INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY, INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  }
}

variable "invoker_members" {
  description = "List of members allowed to invoke the service (format: user:email, serviceAccount:email, or allUsers)"
  type        = list(string)
  default     = []
}

variable "allow_unauthenticated" {
  description = "Allow unauthenticated access (use only for public APIs behind load balancer)"
  type        = bool
  default     = false
}

variable "request_timeout" {
  description = "Request timeout (e.g., '60s', '300s')"
  type        = string
  default     = "300s"
}

variable "max_concurrent_requests" {
  description = "Maximum concurrent requests per instance"
  type        = number
  default     = 80
}

variable "startup_probe_path" {
  description = "Path for startup probe (leave empty to disable)"
  type        = string
  default     = "/health"
}

variable "startup_probe_initial_delay" {
  description = "Startup probe initial delay in seconds"
  type        = number
  default     = 0
}

variable "startup_probe_timeout" {
  description = "Startup probe timeout in seconds"
  type        = number
  default     = 1
}

variable "startup_probe_period" {
  description = "Startup probe period in seconds"
  type        = number
  default     = 10
}

variable "startup_probe_failure_threshold" {
  description = "Startup probe failure threshold"
  type        = number
  default     = 3
}

variable "liveness_probe_path" {
  description = "Path for liveness probe (leave empty to disable)"
  type        = string
  default     = "/health"
}

variable "liveness_probe_initial_delay" {
  description = "Liveness probe initial delay in seconds"
  type        = number
  default     = 10
}

variable "liveness_probe_timeout" {
  description = "Liveness probe timeout in seconds"
  type        = number
  default     = 1
}

variable "liveness_probe_period" {
  description = "Liveness probe period in seconds"
  type        = number
  default     = 10
}

variable "liveness_probe_failure_threshold" {
  description = "Liveness probe failure threshold"
  type        = number
  default     = 3
}

variable "labels" {
  description = "Additional labels for the service"
  type        = map(string)
  default     = {}
}