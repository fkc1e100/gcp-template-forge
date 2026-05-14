provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_container_cluster" "primary" {
  name     = "kuberay-cluster"
  location = var.region

  # Enabling Autopilot or Standard? We'll go Standard for KubeRay flexibility
  remove_default_node_pool = true
  initial_node_cluster     = []

  network    = "default"
  subnetwork = "default"

  ip_allocation_policy {
    use_ip_masquerade_as_nat = true
  }

  deletion_protection = false

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "kuberay-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    machine_type = "e2-standard-4"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
