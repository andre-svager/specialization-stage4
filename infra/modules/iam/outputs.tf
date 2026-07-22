output "gke_node_service_account" {
  description = "Email of the GKE node service account"
  value       = google_service_account.gke_nodes.email
}

output "microservice_service_accounts" {
  description = "Map of microservice names to their service account emails"
  value = {
    for service in var.microservices :
    service => google_service_account.microservices[service].email
  }
}

output "workload_identity_provider" {
  description = "Workload Identity Provider path for GitHub Actions"
  value       = google_iam_workload_identity_pool_provider.github_actions.name
}

output "ci_service_account" {
  description = "Email of the CI/CD service account for GitHub Actions"
  value       = google_service_account.ci_cd.email
}
