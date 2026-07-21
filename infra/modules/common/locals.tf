# Common locals module - Shared naming conventions and patterns

locals {
  # Naming convention: {prefix}-{environment}-{resource}
  name_prefix = "${var.resource_prefix}-${var.environment}"

  # Common labels for GCP resources
  common_labels = merge(var.tags, {
    Environment = var.environment
  })

  # Valid GCP machine types for different workloads
  machine_types = {
    small  = "e2-small"
    medium = "e2-medium"
    large  = "e2-standard-4"
    xlarge = "e2-standard-8"
  }

  # Storage classes based on environment
  storage_classes = {
    dev        = "standard-rwo"
    staging    = "standard-rwo"
    production = "premium-rwo"
  }

  # Database configurations per service
  service_databases = {
    auth = {
      name   = "auth_db"
      user   = "auth_service"
      tables = ["api_keys"]
    }
    flag = {
      name   = "flag_db"
      user   = "flag_service"
      tables = ["flags"]
    }
    target = {
      name   = "target_db"
      user   = "target_service"
      tables = ["events"]
    }
  }
}
