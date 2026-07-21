# ArgoCD installation module for GKE using Terraform

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = var.namespace

  create_namespace = true

  set {
    name  = "server.service.type"
    value = var.service_type
  }

  set {
    name  = "redis.enabled"
    value = "true"
  }

  set {
    name  = "controller.replicas"
    value = var.controller_replicas
  }

  depends_on = [var.gke_cluster_ready]
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_config_map" "argocd_config" {
  metadata {
    name      = "argocd-cm"
    namespace = var.namespace
  }

  data = {
    "application.instanceLabelKey" = "argocd.argoproj.io/instance"
    "repositories" = yamlencode([
      {
        type = "git"
        url  = var.git_repository_url
        name = "gitops-repo"
      }
    ])
    "url" = var.argocd_url
  }
}

resource "kubernetes_secret" "argocd_initial_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = var.namespace
  }

  data = {
    "password" = var.initial_admin_password
  }

  type = "Opaque"
}
