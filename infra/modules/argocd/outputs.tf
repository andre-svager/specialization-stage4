output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = var.argocd_url
}

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = var.namespace
}

output "initial_admin_password" {
  description = "Initial admin password (sensitive)"
  value       = var.initial_admin_password
  sensitive   = true
}
