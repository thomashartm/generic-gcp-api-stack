# Cloud SQL Module Outputs

output "instance_name" {
  description = "Name of the database instance"
  value       = google_sql_database_instance.postgres.name
}

output "instance_connection_name" {
  description = "Connection name for the database instance (for Cloud SQL Proxy)"
  value       = google_sql_database_instance.postgres.connection_name
}

output "private_ip_address" {
  description = "Private IP address of the database instance"
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "database_name" {
  description = "Name of the database"
  value       = google_sql_database.database.name
}

output "database_user" {
  description = "Database user name"
  value       = google_sql_user.user.name
  sensitive   = true
}

output "instance_self_link" {
  description = "Self-link of the database instance"
  value       = google_sql_database_instance.postgres.self_link
}

output "instance_server_ca_cert" {
  description = "CA certificate for the instance"
  value       = google_sql_database_instance.postgres.server_ca_cert
  sensitive   = true
}

output "read_replica_connection_names" {
  description = "Connection names for read replicas"
  value       = [for replica in google_sql_database_instance.read_replica : replica.connection_name]
}

output "read_replica_private_ips" {
  description = "Private IP addresses of read replicas"
  value       = [for replica in google_sql_database_instance.read_replica : replica.private_ip_address]
}