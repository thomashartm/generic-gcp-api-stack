# IAM - Service Accounts

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  # need to rethink it as it is to tangled
  source = "../../../../modules/iam"
}

inputs = {}