# GCP-based infrastructure foundation for ToggleMaster.
# This provisions networking, GKE cluster, IAM, and pod-based Postgres.

module "networking" {
  source = "./modules/networking"

  environment          = var.environment
  network_name         = var.network_name
  region               = var.region
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "iam" {
  source = "./modules/iam"

  environment = var.environment
  project_id  = var.project_id

  depends_on = [module.networking]
}

module "gke" {
  source = "./modules/gke"

  environment  = var.environment
  project_id   = var.project_id
  region       = var.region
  zone         = var.zone
  cluster_name = var.cluster_name
  network      = module.networking.network_name
  subnetwork   = module.networking.private_subnet_names[0]
  node_count   = var.node_count
  machine_type = var.machine_type

  depends_on = [module.networking, module.iam]
}

module "postgres" {
  source = "./modules/postgres"

  environment             = var.environment
  postgres_admin_password = var.postgres_admin_password
  service_db_passwords    = var.service_db_passwords
  kubeconfig_path         = var.kubeconfig_path
}


module "artifact_registry" {
  source     = "./modules/artifact_registry"
  project_id = var.project_id
  location   = var.region
  repositories = [
    "auth-service",
    "analytics-service",
    "evaluation-service",
    "flag-service",
    "target-service",
  ]
}
