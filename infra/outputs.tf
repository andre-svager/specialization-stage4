output "network_name" {
  description = "GCP VPC name"
  value       = module.networking.network_name
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "workload_identity_provider" {
  description = "Workload Identity Provider path for GitHub Actions"
  value       = module.iam.workload_identity_provider
}

output "ci_service_account" {
  description = "Email of the CI/CD service account for GitHub Actions"
  value       = module.iam.ci_service_account
}