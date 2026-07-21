# Common variables module - Shared across all modules to eliminate DRY violations

variable "environment" {
  description = "Environment name (e.g., staging, production)"
  type        = string

  validation {
    condition     = can(regex("^(staging|production|dev)$", var.environment))
    error_message = "Environment must be 'dev', 'staging', or 'production'."
  }
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
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

variable "resource_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "togglemaster"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Project   = "ToggleMaster"
  }
}
