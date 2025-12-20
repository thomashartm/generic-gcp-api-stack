# CloudSQL - PostgreSQL Database

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../modules/cloud-sql"
}

dependency "networking" {
  config_path = "../networking"
}

dependency "secret_manager" {
  config_path = "../secret-manager"
}

inputs = {
  network_id = dependency.networking.outputs.vpc_self_link

  # Database configuration
  database_version = "POSTGRES_15"
  tier             = "db-f1-micro"          # Dev: smallest tier
  availability_type = "ZONAL"                # Dev: no HA
  disk_type        = "PD_SSD"
  disk_size        = 10
  disk_autoresize  = true

  # Database credentials (from secret manager)
  db_name     = dependency.secret_manager.outputs.secret_ids["db_name"]
  db_user     = dependency.secret_manager.outputs.secret_ids["db_user"]
  db_password = "CHANGE_ME_dev_db_password_123!"  # Should match secret-manager password

  # Backups
  point_in_time_recovery_enabled = true
  retained_backups               = 7
  backup_start_time              = "03:00"

  # Deletion protection (disabled for dev to allow easier cleanup)
  deletion_protection = false

  # Read replicas (disabled for dev)
  read_replica_count = 0
}