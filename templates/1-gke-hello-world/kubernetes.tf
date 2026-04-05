data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# Hello World Deployment
resource "kubernetes_deployment" "hello_world" {
  metadata {
    name = "hello-world"
    labels = {
      app = "hello-world"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "hello-world"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-world"
        }
      }

      spec {
        container {
          image = "gcr.io/google-samples/hello-app:1.0"
          name  = "hello-world"

          port {
            container_port = 8080
          }
        }
      }
    }
  }
}

# Hello World Service
resource "kubernetes_service" "hello_world" {
  metadata {
    name = "hello-world-service"
  }

  spec {
    selector = {
      app = "hello-world"
    }

    port {
      port        = 80
      target_port = 8080
    }

    type = "LoadBalancer"
  }
}
