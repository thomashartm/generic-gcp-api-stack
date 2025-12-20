# Secret Manager Module
# Creates secrets for sensitive data like database credentials

# Database password secret
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.environment}-db-password"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Database password secret version
resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}

# Database user secret
resource "google_secret_manager_secret" "db_user" {
  secret_id = "${var.environment}-db-user"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Database user secret version
resource "google_secret_manager_secret_version" "db_user_version" {
  secret      = google_secret_manager_secret.db_user.id
  secret_data = var.db_user
}

# Database name secret
resource "google_secret_manager_secret" "db_name" {
  secret_id = "${var.environment}-db-name"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Database name secret version
resource "google_secret_manager_secret_version" "db_name_version" {
  secret      = google_secret_manager_secret.db_name.id
  secret_data = var.db_name
}

# Additional secrets (optional)
resource "google_secret_manager_secret" "additional_secrets" {
  for_each = var.additional_secrets

  secret_id = "${var.environment}-${each.key}"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "google_secret_manager_secret_version" "additional_secrets_versions" {
  for_each = var.additional_secrets

  secret      = google_secret_manager_secret.additional_secrets[each.key].id
  secret_data = each.value
}

# IAM bindings to allow service accounts to access secrets
resource "google_secret_manager_secret_iam_member" "db_password_accessor" {
  for_each = toset(var.accessor_service_accounts)

  project   = var.project_id
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value
}

resource "google_secret_manager_secret_iam_member" "db_user_accessor" {
  for_each = toset(var.accessor_service_accounts)

  project   = var.project_id
  secret_id = google_secret_manager_secret.db_user.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value
}

resource "google_secret_manager_secret_iam_member" "db_name_accessor" {
  for_each = toset(var.accessor_service_accounts)

  project   = var.project_id
  secret_id = google_secret_manager_secret.db_name.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value
}

resource "google_secret_manager_secret_iam_member" "additional_secrets_accessor" {
  for_each = merge([
    for secret_key in keys(var.additional_secrets) : {
      for sa in var.accessor_service_accounts :
      "${secret_key}-${sa}" => {
        secret_key = secret_key
        sa         = sa
      }
    }
  ]...)

  project   = var.project_id
  secret_id = google_secret_manager_secret.additional_secrets[each.value.secret_key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.sa
}