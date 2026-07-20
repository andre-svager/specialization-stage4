output "namespace" {
  value = kubernetes_namespace.db_infra.metadata[0].name
}

output "service_secret_names" {
  value = { for k, v in kubernetes_secret.service_db_credentials : k => v.metadata[0].name }
}
