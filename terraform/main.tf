terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "burger" {
  metadata {
    name = "burger-tf"
  }
}

resource "kubernetes_deployment" "database" {
  metadata {
    name      = "database"
    namespace = kubernetes_namespace.burger.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "database" }
    }
    template {
      metadata {
        labels = { app = "database" }
      }
      spec {
        container {
          name  = "postgres"
          image = "postgres:15"
          env {
            name  = "POSTGRES_DB"
            value = "burgerhouse"
          }
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = "burger-secrets"
                key  = "db-user"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = "burger-secrets"
                key  = "db-password"
              }
            }
          }
          port {
            container_port = 5432
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "database" {
  metadata {
    name      = "database"
    namespace = kubernetes_namespace.burger.metadata[0].name
  }
  spec {
    selector = { app = "database" }
    port {
      port = 5432
    }
  }
}

resource "kubernetes_deployment" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.burger.metadata[0].name
  }
  spec {
    replicas = 3
    selector {
      match_labels = { app = "backend" }
    }
    template {
      metadata {
        labels = { app = "backend" }
      }
      spec {
        container {
          name              = "backend"
          image             = "burger-backend:latest"
          image_pull_policy = "Never"
          env {
            name  = "DB_HOST"
            value = "database"
          }
          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = "burger-secrets"
                key  = "db-user"
              }
            }
          }
          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = "burger-secrets"
                key  = "db-password"
              }
            }
          }
          env {
            name  = "DB_NAME"
            value = "burgerhouse"
          }
          port {
            container_port = 3000
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.burger.metadata[0].name
  }
  spec {
    selector = { app = "backend" }
    port {
      port = 3000
    }
  }
}

resource "kubernetes_deployment" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace.burger.metadata[0].name
  }
  spec {
    replicas = 2
    selector {
      match_labels = { app = "frontend" }
    }
    template {
      metadata {
        labels = { app = "frontend" }
      }
      spec {
        container {
          name              = "frontend"
          image             = "burger-frontend:latest"
          image_pull_policy = "Never"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace.burger.metadata[0].name
  }
  spec {
    selector = { app = "frontend" }
    port {
      port = 80
    }
  }
}
