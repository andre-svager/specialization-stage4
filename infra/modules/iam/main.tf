# IAM module for GCP service accounts and IAM roles

resource "google_service_account" "gke_nodes" {
  account_id   = "${var.environment}-gke-node-sa"
  display_name = "Service account for GKE nodes"
  description  = "Service account used by GKE nodes for Workload Identity"
}

resource "google_project_iam_member" "gke_nodes_roles" {
  for_each = var.gke_node_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_service_account_iam_member" "gke_workload_identity" {
  for_each = var.workload_identity_services

  service_account_id = google_service_account.gke_nodes.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.namespace}/${each.value.service_account}]"
}

resource "google_service_account" "microservices" {
  for_each = var.microservices

  account_id   = "${var.environment}-${each.key}-sa"
  display_name = "Service account for ${each.key} service"
  description  = "Service account for ${each.key} microservice"
}

resource "google_project_iam_member" "microservices_roles" {
  for_each = var.microservices_iam

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.microservices[each.value.service].email}"
}
