# Terragrunt configuration for the 'dev' environment

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

# Environment-specific inputs
inputs = {
  environment = "dev"
  # IMPORTANT: Update this with your actual GCP project ID
  project_id  = "generic-infra-demo"  # CHANGE THIS!
  region      = "europe-west6"
}