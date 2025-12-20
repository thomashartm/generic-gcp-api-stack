# Load Balancer Module Outputs

output "load_balancer_ip" {
  description = "Global static IP address of the load balancer"
  value       = google_compute_global_address.default.address
}

output "load_balancer_ip_name" {
  description = "Name of the global IP address resource"
  value       = google_compute_global_address.default.name
}

output "ssl_certificate_id" {
  description = "ID of the SSL certificate (empty if no domains configured)"
  value       = length(google_compute_managed_ssl_certificate.default) > 0 ? google_compute_managed_ssl_certificate.default[0].id : ""
}

output "ssl_certificate_status" {
  description = "Status of the SSL certificate"
  value       = length(google_compute_managed_ssl_certificate.default) > 0 ? google_compute_managed_ssl_certificate.default[0].managed[0].status : ""
}

output "backend_service_id" {
  description = "ID of the backend service"
  value       = google_compute_backend_service.default.id
}

output "url_map_id" {
  description = "ID of the URL map"
  value       = google_compute_url_map.default.id
}

output "security_policy_id" {
  description = "ID of the Cloud Armor security policy (empty if disabled)"
  value       = var.enable_cloud_armor ? google_compute_security_policy.policy[0].id : ""
}

output "https_forwarding_rule_id" {
  description = "ID of the HTTPS forwarding rule"
  value       = length(google_compute_global_forwarding_rule.https) > 0 ? google_compute_global_forwarding_rule.https[0].id : ""
}

output "http_forwarding_rule_id" {
  description = "ID of the HTTP forwarding rule (empty if HTTP redirect disabled)"
  value       = var.enable_http_redirect && length(google_compute_global_forwarding_rule.http) > 0 ? google_compute_global_forwarding_rule.http[0].id : ""
}