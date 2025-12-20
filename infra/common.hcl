# Common configuration shared across all environments
# This file contains helper functions and shared locals

locals {
  # Common labels to apply to all resources
  common_labels = {
    managed_by = "terraform"
    repository = "generic-gcp-api-stack"
  }

  # Common naming convention
  # Format: {environment}-{service}-{resource_type}
  name_prefix = "${local.environment}"

  # Parse environment from path
  path_parts = split("/", get_terragrunt_dir())
  environment = try(
    element(local.path_parts, index(local.path_parts, "stacks") + 1),
    "unknown"
  )
}

# Helper function to generate resource names
# Usage: dependency.common.outputs.resource_name("api", "service")
# Result: "dev-api-service"
terraform {
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
  }
}