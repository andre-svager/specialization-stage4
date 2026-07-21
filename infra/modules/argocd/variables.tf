variable "namespace" {
  description = "Namespace for ArgoCD installation"
  type        = string
  default     = "argocd"
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.0"
}

variable "service_type" {
  description = "Kubernetes service type for ArgoCD server"
  type        = string
  default     = "LoadBalancer"
}

variable "controller_replicas" {
  description = "Number of ArgoCD application controller replicas"
  type        = number
  default     = 1
}

variable "git_repository_url" {
  description = "Git repository URL for ArgoCD to monitor"
  type        = string
  default     = "https://github.com/andre-svager/specialization-stage4.git"
}

variable "argocd_url" {
  description = "External URL for ArgoCD UI"
  type        = string
  default     = "https://argocd.example.com"
}

variable "initial_admin_password" {
  description = "Initial admin password for ArgoCD"
  type        = string
  sensitive   = true
}

variable "gke_cluster_ready" {
  description = "Dependency on GKE cluster being ready"
  type        = any
  default     = null
}
