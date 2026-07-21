resource "google_artifact_registry_repository" "repos" {
  for_each = toset(var.repositories)

  project       = var.project_id
  location      = var.location
  repository_id = each.value
  description   = "Artifact Registry repository for ${each.value}"
  format        = "DOCKER"

  # Optional: set a repository with Docker cleanup policy or retention via IAM lifecycle
}
