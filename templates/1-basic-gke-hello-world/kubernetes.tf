data "google_client_config" "default" {}

locals {
  app_name = "hello-world"
}

# NOTE: Configuring the Kubernetes provider using attributes from a cluster created in the same 
# state can lead to errors during plan. For production use, it is best to separate the cluster
# infrastructure and the Kubernetes resource management into different states.
provider "kubernetes" {
  host                   = "https://${google_container_cluster.hello_world_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.hello_world_cluster.master_auth[0].cluster_ca_certificate)
}

resource "kubernetes_namespace" "hello_world" {
  metadata {
    name = local.app_name
  }
}

resource "kubernetes_deployment" "hello_world" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace.hello_world.metadata[0].name
    labels = {
      app = local.app_name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = local.app_name
      }
    }

    template {
      metadata {
        labels = {
          app = local.app_name
        }
      }

      spec {
        container {
          image = "us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0"
          name  = local.app_name

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            run_as_user                = 1000

            capabilities {
              drop = ["ALL"]
            }
          }

          port {
            container_port = 8080
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "hello_world" {
  metadata {
    name      = "${local.app_name}-service"
    namespace = kubernetes_namespace.hello_world.metadata[0].name
  }

  spec {
    selector = {
      app = local.app_name
    }

    port {
      port        = 80
      target_port = 8080
    }

    type = "LoadBalancer"
  }
}
