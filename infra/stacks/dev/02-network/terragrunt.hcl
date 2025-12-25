# Terragrunt configuration for the 'dev' environment

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

# Environment-specific inputs
inputs = {
}