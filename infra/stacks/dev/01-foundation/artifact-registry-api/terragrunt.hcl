# Artifact Registry - Docker Repository

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../../modules/artifact-registry"
}

dependency "iam" {
  config_path = "../iam"
}

inputs = {
  repository_id = "api"

  # Allow Cloud Run services to pull images
  reader_service_accounts = [
    "serviceAccount:${dependency.iam.outputs.api_service_account_email}",
    "serviceAccount:${dependency.iam.outputs.event_processor_service_account_email}"
  ]

  # Add your user or CI/CD service account here to push images
  writer_members = []
}