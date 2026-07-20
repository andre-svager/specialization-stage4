output "network_name" {
  description = "VPC name"
  value       = google_compute_network.main.name
}

output "network_id" {
  description = "VPC ID"
  value       = google_compute_network.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = google_compute_subnetwork.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = google_compute_subnetwork.private[*].id
}

output "public_subnet_names" {
  description = "List of public subnet names"
  value       = google_compute_subnetwork.public[*].name
}

output "private_subnet_names" {
  description = "List of private subnet names"
  value       = google_compute_subnetwork.private[*].name
}
