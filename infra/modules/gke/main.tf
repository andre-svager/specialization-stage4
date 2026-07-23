# GKE module for ToggleMaster

resource "google_service_account" "default" {
  account_id   = "${var.environment}-gke-sa"
  display_name = "Service account for GKE nodes"
}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 2

  network    = var.network
  subnetwork = var.subnetwork

  deletion_protection = false

  ip_allocation_policy {}

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  node_config {
    machine_type = "e2-standard-2"  # Increased from e2-medium for more CPU
    disk_size_gb = 20   # Minimum 12GB required for COS image
    disk_type    = "pd-standard"
    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
