# Secret Manager Module Outputs

output "db_password_secret_id" {
  description = "ID of the database password secret"
  value       = google_secret_manager_secret.db_password.secret_id
}

output "db_password_secret_name" {
  description = "Full resource name of the database password secret"
  value       = google_secret_manager_secret.db_password.name
}

output "db_user_secret_id" {
  description = "ID of the database user secret"
  value       = google_secret_manager_secret.db_user.secret_id
}

output "db_user_secret_name" {
  description = "Full resource name of the database user secret"
  value       = google_secret_manager_secret.db_user.name
}

output "db_name_secret_id" {
  description = "ID of the database name secret"
  value       = google_secret_manager_secret.db_name.secret_id
}

output "db_name_secret_name" {
  description = "Full resource name of the database name secret"
  value       = google_secret_manager_secret.db_name.name
}

output "secret_ids" {
  description = "Map of secret names to their IDs"
  value = merge(
    {
      db_password = google_secret_manager_secret.db_password.secret_id
      db_user     = google_secret_manager_secret.db_user.secret_id
      db_name     = google_secret_manager_secret.db_name.secret_id
    },
    { for k, v in google_secret_manager_secret.additional_secrets : k => v.secret_id }
  )
}

output "secret_names" {
  description = "Map of secret names to their full resource names"
  value = merge(
    {
      db_password = google_secret_manager_secret.db_password.name
      db_user     = google_secret_manager_secret.db_user.name
      db_name     = google_secret_manager_secret.db_name.name
    },
    { for k, v in google_secret_manager_secret.additional_secrets : k => v.name }
  )
}