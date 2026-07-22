variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gke_node_roles" {
  description = "IAM roles to assign to GKE node service account"
  type        = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/storage.objectViewer", # For pulling images from Artifact Registry
  ]
}

variable "workload_identity_services" {
  description = "Workload Identity mappings for Kubernetes service accounts"
  type = map(object({
    namespace       = string
    service_account = string
  }))
  default = {
    analytics  = { namespace = "default", service_account = "analytics-service" }
    auth       = { namespace = "default", service_account = "auth-service" }
    evaluation = { namespace = "default", service_account = "evaluation-service" }
    flag       = { namespace = "default", service_account = "flag-service" }
    target     = { namespace = "default", service_account = "target-service" }
  }
}

variable "microservices" {
  description = "List of microservices that need dedicated service accounts"
  type        = list(string)
  default     = ["analytics", "auth", "evaluation", "flag", "target"]
}

variable "microservices_iam" {
  description = "IAM roles to assign to microservice service accounts"
  type = list(object({
    service = string
    role    = string
  }))
  default = [
    # Example: Add specific IAM roles for services that need GCP API access
    # { service = "analytics", role = "roles/cloudsql.client" }
  ]
}
