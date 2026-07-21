variable "environment" {
  description = "Environment name"
  type        = string
}

variable "postgres_admin_password" {
  description = "Password for the Postgres admin user"
  type        = string
  sensitive   = true
}

variable "service_db_passwords" {
  description = "Map of service keys to DB passwords (e.g. { auth=..., flag=..., target=... })"
  type        = map(string)
  sensitive   = true
}

variable "kubeconfig_path" {
  description = "Optional kubeconfig path for the kubernetes provider (leave empty to use default)"
  type        = string
  default     = ""
}
