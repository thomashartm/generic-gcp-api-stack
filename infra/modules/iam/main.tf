# IAM Module
# Creates service accounts and IAM bindings for Cloud Run services

# Service Account for API Cloud Run
resource "google_service_account" "api_service" {
  account_id   = "${var.environment}-api-sa"
  display_name = "${var.environment} API Service Account"
  description  = "Service account for the API Cloud Run service"
  project      = var.project_id
}

# Service Account for Event Processor Cloud Run
resource "google_service_account" "event_processor" {
  account_id   = "${var.environment}-event-processor-sa"
  display_name = "${var.environment} Event Processor Service Account"
  description  = "Service account for the Event Processor Cloud Run service"
  project      = var.project_id
}

# IAM Bindings for API Service Account

# Cloud SQL Client - allows connecting to CloudSQL
resource "google_project_iam_member" "api_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.api_service.email}"
}

# Pub/Sub Publisher - allows publishing events
resource "google_project_iam_member" "api_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.api_service.email}"
}

# Secret Manager Secret Accessor - allows reading secrets
resource "google_project_iam_member" "api_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.api_service.email}"
}

# IAM Bindings for Event Processor Service Account

# Cloud SQL Client - allows connecting to CloudSQL
resource "google_project_iam_member" "event_processor_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.event_processor.email}"
}

# Pub/Sub Subscriber - allows receiving events
resource "google_project_iam_member" "event_processor_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.event_processor.email}"
}

# Secret Manager Secret Accessor - allows reading secrets
resource "google_project_iam_member" "event_processor_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.event_processor.email}"
}

# Cloud Trace Agent - allows writing traces (both services)
resource "google_project_iam_member" "api_trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.api_service.email}"
}

resource "google_project_iam_member" "event_processor_trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.event_processor.email}"
}

# Logging - allows writing logs (both services)
resource "google_project_iam_member" "api_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.api_service.email}"
}

resource "google_project_iam_member" "event_processor_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.event_processor.email}"
}

# Monitoring Metric Writer - allows writing custom metrics (both services)
resource "google_project_iam_member" "api_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.api_service.email}"
}

resource "google_project_iam_member" "event_processor_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.event_processor.email}"
}