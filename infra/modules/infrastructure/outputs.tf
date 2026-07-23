output "analytics_topic_name" {
  value = google_pubsub_topic.analytics_events.name
}

output "analytics_subscription_name" {
  value = google_pubsub_subscription.analytics_worker.name
}