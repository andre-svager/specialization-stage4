output "repositories" {
  value = { for k, v in google_artifact_registry_repository.repos : k => v.name }
}
