# Pub/Sub Module
# Creates Pub/Sub topics and subscriptions for event processing

# Main events topic
resource "google_pubsub_topic" "events" {
  name    = "${var.environment}-events-topic"
  project = var.project_id

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  message_retention_duration = var.message_retention_duration
}

# Dead letter topic for failed messages
resource "google_pubsub_topic" "dead_letter" {
  name    = "${var.environment}-events-dead-letter-topic"
  project = var.project_id

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "dead-letter"
  }

  message_retention_duration = var.dead_letter_retention_duration
}

# Push subscription to Event Processor Cloud Run
resource "google_pubsub_subscription" "events_push" {
  name    = "${var.environment}-events-subscription"
  topic   = google_pubsub_topic.events.name
  project = var.project_id

  # Push configuration
  push_config {
    push_endpoint = var.event_processor_url

    # Use OIDC token for authentication
    oidc_token {
      service_account_email = var.event_processor_service_account
    }

    attributes = {
      x-goog-version = "v1"
    }
  }

  # Acknowledgement deadline
  ack_deadline_seconds = var.ack_deadline_seconds

  # Message retention
  message_retention_duration = var.subscription_message_retention

  # Retry policy
  retry_policy {
    minimum_backoff = var.retry_minimum_backoff
    maximum_backoff = var.retry_maximum_backoff
  }

  # Dead letter policy
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = var.max_delivery_attempts
  }

  # Expiration policy (never expire)
  expiration_policy {
    ttl = ""
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  depends_on = [google_pubsub_topic.dead_letter]
}

# Subscription for dead letter topic (pull subscription for manual inspection)
resource "google_pubsub_subscription" "dead_letter_pull" {
  name    = "${var.environment}-events-dead-letter-subscription"
  topic   = google_pubsub_topic.dead_letter.name
  project = var.project_id

  # Pull subscription for manual inspection
  ack_deadline_seconds = 600

  # Retain messages for 7 days
  message_retention_duration = "604800s"

  # Never expire
  expiration_policy {
    ttl = ""
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "dead-letter-inspection"
  }
}

# IAM bindings for publishers (API service)
resource "google_pubsub_topic_iam_member" "publishers" {
  for_each = toset(var.publisher_service_accounts)

  project = var.project_id
  topic   = google_pubsub_topic.events.name
  role    = "roles/pubsub.publisher"
  member  = each.value
}

# IAM binding for Pub/Sub to invoke Cloud Run
resource "google_cloud_run_service_iam_member" "pubsub_invoker" {
  count = var.event_processor_url != "" ? 1 : 0

  project  = var.project_id
  location = var.region
  service  = var.event_processor_service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# IAM binding for event processor service account to subscribe
resource "google_pubsub_subscription_iam_member" "subscriber" {
  project      = var.project_id
  subscription = google_pubsub_subscription.events_push.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.event_processor_service_account}"
}

# IAM binding for Pub/Sub service account to publish to dead letter topic
resource "google_pubsub_topic_iam_member" "dead_letter_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.dead_letter.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# IAM binding for dead letter subscription
resource "google_pubsub_subscription_iam_member" "dead_letter_subscriber" {
  project      = var.project_id
  subscription = google_pubsub_subscription.dead_letter_pull.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# Get project data for service account
data "google_project" "project" {
  project_id = var.project_id
}