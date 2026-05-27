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

resource "kubernetes_config_map" "burger_config" {
  metadata {
    name      = "burger-config"
    namespace = kubernetes_namespace.burger.metadata[0].name
  }
  data = {
    DB_HOST = "database"
    DB_NAME = "burgerhouse"
    DB_PORT = "5432"
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
            name = "DB_HOST"
            value_from {
              config_map_key_ref {
                name = "burger-config"
                key  = "DB_HOST"
              }
            }
          }
          env {
            name = "DB_NAME"
            value_from {
              config_map_key_ref {
                name = "burger-config"
                key  = "DB_NAME"
              }
            }
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
          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }
          liveness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 15
            period_seconds        = 10
          }
          readiness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 10
            period_seconds        = 5
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

resource "kubernetes_ingress_v1" "burger" {
  metadata {
    name      = "burger-ingress"
    namespace = kubernetes_namespace.burger.metadata[0].name
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "burger.local"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "bestillinger" {
  metadata {
    name      = "bestillinger-ingress"
    namespace = kubernetes_namespace.burger.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/configuration-snippet" = "rewrite ^/$ /bestillinger.html break;"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "bestillinger.local"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
