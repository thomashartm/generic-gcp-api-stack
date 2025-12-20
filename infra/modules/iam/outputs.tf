# IAM Module Outputs

output "api_service_account_email" {
  description = "Email of the API service account"
  value       = google_service_account.api_service.email
}

output "api_service_account_id" {
  description = "ID of the API service account"
  value       = google_service_account.api_service.id
}

output "event_processor_service_account_email" {
  description = "Email of the Event Processor service account"
  value       = google_service_account.event_processor.email
}

output "event_processor_service_account_id" {
  description = "ID of the Event Processor service account"
  value       = google_service_account.event_processor.id
}

output "service_account_emails" {
  description = "Map of service account names to their emails"
  value = {
    api             = google_service_account.api_service.email
    event_processor = google_service_account.event_processor.email
  }
}