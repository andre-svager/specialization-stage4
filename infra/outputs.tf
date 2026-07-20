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

output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = module.eks.cluster_name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "gke_cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
}
