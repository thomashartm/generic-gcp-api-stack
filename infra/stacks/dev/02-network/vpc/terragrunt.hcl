# Networking - VPC and VPC Connector

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../../modules/vpc"
}

inputs = {
  vpc_connector_cidr         = "10.8.0.0/28"
  vpc_connector_min_instances = 2
  vpc_connector_max_instances = 3
}