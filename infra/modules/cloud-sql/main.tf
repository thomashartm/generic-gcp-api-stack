# Cloud SQL Module
# Creates PostgreSQL database instance with private IP

# Random ID for instance name to allow recreation
resource "random_id" "db_instance_suffix" {
  byte_length = 4
}

# CloudSQL PostgreSQL Instance
resource "google_sql_database_instance" "postgres" {
  name             = "${var.environment}-postgres-${random_id.db_instance_suffix.hex}"
  database_version = var.database_version
  region           = var.region
  project          = var.project_id

  # Prevent accidental deletion
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_type         = var.disk_type
    disk_size         = var.disk_size
    disk_autoresize   = var.disk_autoresize

    # Backup configuration
    backup_configuration {
      enabled                        = true
      start_time                     = var.backup_start_time
      point_in_time_recovery_enabled = var.point_in_time_recovery_enabled
      transaction_log_retention_days = var.transaction_log_retention_days
      backup_retention_settings {
        retained_backups = var.retained_backups
        retention_unit   = "COUNT"
      }
    }

    # IP configuration - Private IP only
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.network_id
      enable_private_path_for_google_cloud_services = true
    }

    # Maintenance window
    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = var.maintenance_window_update_track
    }

    # Database flags
    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = database_flags.value.name
        value = database_flags.value.value
      }
    }

    # Insights configuration
    insights_config {
      query_insights_enabled  = var.query_insights_enabled
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }

    user_labels = {
      environment = var.environment
      managed_by  = "terraform"
    }
  }

  # Depend on private service connection
  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# Private VPC Connection
# Allocate IP range for private service connection
resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.environment}-private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network_id
  project       = var.project_id
}

# Create private VPC connection
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Database
resource "google_sql_database" "database" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id
}

# Database user
resource "google_sql_user" "user" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
  project  = var.project_id
}

# Read replica (optional, for production)
resource "google_sql_database_instance" "read_replica" {
  count = var.read_replica_count

  name                 = "${var.environment}-postgres-replica-${count.index}-${random_id.db_instance_suffix.hex}"
  master_instance_name = google_sql_database_instance.postgres.name
  region               = var.region
  project              = var.project_id

  replica_configuration {
    failover_target = false
  }

  settings {
    tier              = var.replica_tier != "" ? var.replica_tier : var.tier
    availability_type = "ZONAL"
    disk_type         = var.disk_type
    disk_size         = var.disk_size
    disk_autoresize   = var.disk_autoresize

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
    }

    user_labels = {
      environment = var.environment
      managed_by  = "terraform"
      replica     = "true"
    }
  }
  database_version = var.database_version

  # Depend on private service connection
  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# Service Account for Cloud SQL Proxy
resource "google_service_account" "cloud_sql_proxy" {
  account_id   = "${var.environment}-cloud-sql-proxy"
  display_name = "Service Account for Cloud SQL Proxy"
  project      = var.project_id
}
}