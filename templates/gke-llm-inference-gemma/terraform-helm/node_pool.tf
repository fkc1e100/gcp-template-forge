# GPU Node Pool
resource "google_container_node_pool" "gpu_pool" {
  name           = "gpu-pool"
  location       = var.region
  # Restrict to us-central1-c only: -a and -b have chronic L4 spot stockouts.
  # If stockouts persist here, try us-east1-b or us-east4-a as a secondary pool.
  node_locations = ["${var.region}-c"]
  cluster        = google_container_cluster.primary.name
  node_count     = 1

  node_config {
    # DWS flex-start: spot=false + queued_provisioning=true means non-preemptible
    # once provisioned, but draws from the larger preemptible quota pool.
    spot         = false
    machine_type = "g2-standard-12"

    guest_accelerator {
      type  = "nvidia-l4"
      count = 1

      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }

    service_account = var.service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      "nvidia.com/gpu" = "present"
      template         = "gke-llm-inference-gemma"
    }

    taint {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NO_SCHEDULE"
    }
  }

  queued_provisioning {
    enabled = true
  }
}
