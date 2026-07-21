# Common outputs module - Shared outputs used by other modules

output "name_prefix" {
  description = "Standardized name prefix for resources"
  value       = local.name_prefix
}

output "common_labels" {
  description = "Common labels for GCP resources"
  value       = local.common_labels
}

output "storage_class" {
  description = "Storage class based on environment"
  value       = local.storage_classes[var.environment]
}

output "service_databases" {
  description = "Database configurations per service"
  value       = local.service_databases
}
