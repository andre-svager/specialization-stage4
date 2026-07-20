variable "environment" {
  description = "Environment name (e.g., staging, production)"
  type        = string
}

variable "network_name" {
  description = "Name of the GCP VPC"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}
