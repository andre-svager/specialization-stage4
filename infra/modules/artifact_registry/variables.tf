variable "project_id" {
  description = "GCP project for Artifact Registry"
  type        = string
}

variable "location" {
  description = "GCP region/location for repositories"
  type        = string
  default     = "us-central1-a"
}

variable "repositories" {
  description = "List of Artifact Registry repository ids to create"
  type        = list(string)
  default     = []
}
