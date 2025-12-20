# Pub/Sub Module Outputs

output "topic_id" {
  description = "ID of the Pub/Sub topic"
  value       = google_pubsub_topic.events.id
}

output "topic_name" {
  description = "Name of the Pub/Sub topic"
  value       = google_pubsub_topic.events.name
}

output "subscription_id" {
  description = "ID of the Pub/Sub subscription"
  value       = google_pubsub_subscription.events_push.id
}

output "subscription_name" {
  description = "Name of the Pub/Sub subscription"
  value       = google_pubsub_subscription.events_push.name
}

output "dead_letter_topic_id" {
  description = "ID of the dead letter topic"
  value       = google_pubsub_topic.dead_letter.id
}

output "dead_letter_topic_name" {
  description = "Name of the dead letter topic"
  value       = google_pubsub_topic.dead_letter.name
}

output "dead_letter_subscription_id" {
  description = "ID of the dead letter subscription"
  value       = google_pubsub_subscription.dead_letter_pull.id
}

output "dead_letter_subscription_name" {
  description = "Name of the dead letter subscription"
  value       = google_pubsub_subscription.dead_letter_pull.name
}