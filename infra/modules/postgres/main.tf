terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path != "" ? var.kubeconfig_path : null
}

resource "kubernetes_namespace" "db_infra" {
  metadata {
    name = "db-infra"
  }
}

resource "kubernetes_secret" "postgres_admin" {
  metadata {
    name      = "postgres-secret"
    namespace = kubernetes_namespace.db_infra.metadata[0].name
  }

  data = {
    POSTGRES_PASSWORD = var.postgres_admin_password
    POSTGRES_USER     = "postgres"
  }

  type = "Opaque"
}

resource "kubernetes_config_map" "postgres_init" {
  metadata {
    name      = "postgres-init-scripts"
    namespace = kubernetes_namespace.db_infra.metadata[0].name
  }

  data = {
    "init-multi-db.sql" = local.init_sql
  }
}

resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.db_infra.metadata[0].name
    labels = {
      app = "postgres"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "postgres" }
    }

    template {
      metadata {
        labels = { app = "postgres" }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:15"

          port {
            container_port = 5432
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.postgres_admin.metadata[0].name
            }
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }

          volume_mount {
            name       = "init-scripts"
            mount_path = "/docker-entrypoint-initdb.d"
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres"]
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres"]
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }
        }

        volume {
          name = "postgres-storage"
          empty_dir {}
        }

        volume {
          name = "init-scripts"
          config_map {
            name = kubernetes_config_map.postgres_init.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.db_infra.metadata[0].name
  }

  spec {
    selector = { app = "postgres" }

    port {
      port        = 5432
      target_port = 5432
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_network_policy" "postgres_allow_microservices" {
  metadata {
    name      = "allow-microservices-to-postgres"
    namespace = kubernetes_namespace.db_infra.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = { app = "postgres" }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = { "db-client" = "true" }
        }
      }
      ports {
        port     = "5432"
        protocol = "TCP"
      }
    }
  }
}

locals {
  init_sql = <<-SQL
    CREATE DATABASE auth_db;
    CREATE DATABASE flag_db;
    CREATE DATABASE target_db;

    \c auth_db
    CREATE TABLE IF NOT EXISTS api_keys (
      id SERIAL PRIMARY KEY,
      name VARCHAR(255) NOT NULL,
      key VARCHAR(255) UNIQUE NOT NULL,
      active BOOLEAN DEFAULT true,
      created_at TIMESTAMP DEFAULT now()
    );

    \c flag_db
    CREATE TABLE IF NOT EXISTS flags (
      id SERIAL PRIMARY KEY,
      name VARCHAR(255) UNIQUE NOT NULL,
      enabled BOOLEAN DEFAULT false
    );

    \c target_db
    CREATE TABLE IF NOT EXISTS events (
      event_id VARCHAR(255) PRIMARY KEY,
      flag_name VARCHAR(255),
      user_id VARCHAR(255),
      created_at TIMESTAMP DEFAULT now()
    );
  SQL
}

locals {
  microservices_dbs = {
    auth   = { db = "auth_db", user = "auth_service" }
    flag   = { db = "flag_db", user = "flag_service" }
    target = { db = "target_db", user = "target_service" }
  }
}

resource "kubernetes_secret" "service_db_credentials" {
  for_each = local.microservices_dbs

  metadata {
    name      = "${each.key}-db-credentials"
    namespace = kubernetes_namespace.db_infra.metadata[0].name
  }

  data = {
    DATABASE_URL = "postgres://${each.value.user}:${var.service_db_passwords[each.key]}@postgres.db-infra.svc.cluster.local:5432/${each.value.db}"
  }

  type = "Opaque"
}
