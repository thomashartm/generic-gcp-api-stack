# Secret Manager - Secrets

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../modules/secret-manager"
}

dependency "iam" {
  config_path = "../iam"
}

inputs = {
  # Database credentials
  db_user     = "appuser"
  db_name     = "appdb"
  db_password = "CHANGE_ME_dev_db_password_123!"  # CHANGE THIS! Use env var: TF_VAR_db_password

  # Service accounts that can access secrets
  accessor_service_accounts = [
    "serviceAccount:${dependency.iam.outputs.api_service_account_email}",
    "serviceAccount:${dependency.iam.outputs.event_processor_service_account_email}"
  ]

  # Optional additional secrets (e.g., JWT secret, API keys)
  additional_secrets = {}
}