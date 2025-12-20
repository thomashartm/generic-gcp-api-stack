# Pub/Sub - Event Topics and Subscriptions

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../modules/pubsub"
}

dependency "iam" {
  config_path = "../iam"
}

dependency "event_processor" {
  config_path = "../event-processor"
}

inputs = {
  # Event Processor Cloud Run service details
  event_processor_url             = dependency.event_processor.outputs.service_url
  event_processor_service_name    = dependency.event_processor.outputs.service_name
  event_processor_service_account = dependency.iam.outputs.event_processor_service_account_email

  # Publishers (API service)
  publisher_service_accounts = [
    "serviceAccount:${dependency.iam.outputs.api_service_account_email}"
  ]

  # Configuration
  ack_deadline_seconds  = 60
  max_delivery_attempts = 5

  message_retention_duration = "86400s"  # 24 hours
  dead_letter_retention_duration = "604800s"  # 7 days
}