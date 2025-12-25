# Cloud Run - Event Processor Service

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../modules/cloud-run"
}

dependency "iam" {
  config_path = "../iam"
}

dependency "networking" {
  config_path = "../networking"
}

dependency "database" {
  config_path = "../database"
}

dependency "secret_manager" {
  config_path = "../secret-manager"
}

dependency "artifact_registry" {
  config_path = "../artifact-registry"
}

inputs = {
  service_name          = "event-processor"
  service_account_email = dependency.iam.outputs.event_processor_service_account_email
  vpc_connector_id      = dependency.networking.outputs.vpc_connector_id

  # IMPORTANT: Update this with your actual image URL after building and pushing
  image_url = "${dependency.artifact_registry.outputs.repository_url}/event-processor:latest"

  # Scaling - Dev environment
  min_instances = 0  # Scale to zero to save costs
  max_instances = 2

  # Resources - Dev environment
  cpu_limit    = "1"
  memory_limit = "512Mi"
  cpu_always_allocated = false
  startup_cpu_boost    = true

  # Security - Only Pub/Sub can invoke (configured in pubsub module)
  ingress                = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  allow_unauthenticated  = false

  # VPC egress
  vpc_egress = "PRIVATE_RANGES_ONLY"

  # Environment variables
  env_vars = {
    NODE_ENV = "development"
    PORT     = "3000"
    DB_HOST  = dependency.database.outputs.private_ip_address
  }

  # Secrets from Secret Manager
  secrets = {
    DB_PASSWORD = {
      secret_name = dependency.secret_manager.outputs.db_password_secret_id
      version     = "latest"
    }
    DB_USER = {
      secret_name = dependency.secret_manager.outputs.db_user_secret_id
      version     = "latest"
    }
    DB_NAME = {
      secret_name = dependency.secret_manager.outputs.db_name_secret_id
      version     = "latest"
    }
  }

  # Health check
  startup_probe_path  = "/health"
  liveness_probe_path = "/health"

  # Request timeout (for event processing)
  request_timeout         = "300s"
  max_concurrent_requests = 80
}