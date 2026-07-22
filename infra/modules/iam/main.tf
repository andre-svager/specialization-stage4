# IAM module for GCP service accounts and IAM roles

resource "google_service_account" "gke_nodes" {
  account_id   = "${var.environment}-gke-node-sa"
  display_name = "Service account for GKE nodes"
  description  = "Service account used by GKE nodes for Workload Identity"
}

resource "google_project_iam_member" "gke_nodes_roles" {
  for_each = toset(var.gke_node_roles)

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
  for_each = { for svc in var.microservices : svc => svc }

  account_id   = "${var.environment}-${each.key}-sa"
  display_name = "Service account for ${each.key} service"
  description  = "Service account for ${each.key} microservice"
}

resource "google_project_iam_member" "microservices_roles" {
  for_each = { for m in var.microservices_iam : m.service => m }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.microservices[each.value.service].email}"
}

# Workload Identity Pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github_actions" {
  provider = google-beta
  project  = var.project_id
  workload_identity_pool_id = "github-actions-pool"
  display_name = "GitHub Actions Pool"
  disabled = false
}
 
# Workload Identity Provider for GitHub Actions
resource "google_iam_workload_identity_pool_provider" "github_actions" {
  provider = google-beta
  project  = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions-provider"
  display_name = "GitHub Actions Provider"

  attribute_mapping = {
    "google.subject"        = "assertion.sub"
    "attribute.repository"  = "assertion.repository"
  }

  attribute_condition = "assertion.repository == 'andre-svager/specialization-stage4'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}
 
# Service Account for CI/CD
resource "google_service_account" "ci_cd" {
  account_id   = "ci-service-account"
  display_name = "CI/CD Service Account"
  description  = "Service account for GitHub Actions CI/CD"
}
 
# Grant Workload Identity User to CI/CD SA
resource "google_service_account_iam_member" "github_actions_workload_identity" {
  provider           = google-beta
  service_account_id = google_service_account.ci_cd.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/andre-svager/specialization-stage4"
}
