# Infrastructure module: Firestore (replaces DynamoDB) + Pub/Sub (replaces SQS)
# Service accounts and IAM bindings for these resources live in modules/iam,
# not here, to avoid duplicate account_id declarations across modules.

# --- Firestore ---
resource "google_project_service" "firestore" {
  service = "firestore.googleapis.com"
}

resource "google_firestore_database" "default" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.firestore]
}

# --- Pub/Sub ---
resource "google_project_service" "pubsub" {
  service = "pubsub.googleapis.com"
}

resource "google_pubsub_topic" "analytics_events" {
  name = "toggle-master-analytics-events"

  depends_on = [google_project_service.pubsub]
}

resource "google_pubsub_subscription" "analytics_worker" {
  name                 = "toggle-master-analytics-worker-sub"
  topic                = google_pubsub_topic.analytics_events.name
  ack_deadline_seconds = 20
}