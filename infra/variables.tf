variable "project_id" {
  description = "GCP project ID"
  type        = string
  default = "fiap-502903"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment name (e.g., staging, production)"
  type        = string
  default     = "staging"

  validation {
    condition     = can(regex("^(dev|staging|production)$", var.environment))
    error_message = "Environment must be 'dev', 'staging', or 'production'."
  }
}

# ========== VPC / Networking ==========

variable "network_name" {
  description = "Name of the GCP VPC"
  type        = string
  default     = "togglemaster-vpc"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.1.0.0/24", "10.1.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.1.10.0/24", "10.1.11.0/24"]
}

# ========== GKE Configuration ==========

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "togglemaster-gke"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-medium"
}

variable "kubeconfig_path" {
  description = "Optional kubeconfig path for the kubernetes provider"
  type        = string
  default     = ""
}
