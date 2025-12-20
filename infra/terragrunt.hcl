# Root Terragrunt Configuration
# This file defines common settings for all environments

locals {
  # Parse the path to extract environment information
  parsed = regex(".*/stacks/(?P<environment>[^/]+)/.*", get_terragrunt_dir())
  environment = try(local.parsed.environment, "")

  # Get project ID from environment variable or from the environment config
  project_id = get_env("TG_PROJECT_ID", "")
}

# Remote state configuration
# State files will be stored in GCS bucket created during setup
remote_state {
  backend = "gcs"

  config = {
    project  = local.project_id
    location = "europe-west6"
    bucket   = "${local.project_id}-terraform-state"
    prefix   = "${path_relative_to_include()}"

    # Enable versioning for state files
    enable_bucket_versioning = true
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

# Generate provider configuration for all modules
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<-EOF
    terraform {
      required_version = ">= 1.5.0"

      required_providers {
        google = {
          source  = "hashicorp/google"
          version = "~> 5.0"
        }
        google-beta = {
          source  = "hashicorp/google-beta"
          version = "~> 5.0"
        }
      }
    }

    provider "google" {
      project = var.project_id
      region  = var.region
    }

    provider "google-beta" {
      project = var.project_id
      region  = var.region
    }
  EOF
}

# Common inputs that will be merged with each module's inputs
inputs = {
  region = "europe-west6"
}