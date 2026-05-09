terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = "default"
  subnetwork               = "default"

  deletion_protection = false

  resource_labels = {
    project = "gcp-template-forge"
  }

  ip_allocation_policy {
  }

  vertical_pod_autoscaling {
    enabled = true
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

resource "google_container_node_pool" "gpu_pool" {
  name       = "${var.cluster_name}-gpu-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_locations = [
    "${var.region}-a",
    "${var.region}-b",
    "${var.region}-c",
  ]

  node_config {
    machine_type = "n1-standard-4"
    guest_accelerator {
      type  = "nvidia-tesla-t4"
      count = 1
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      nvidia-t4 = "true"
      project   = "gcp-template-forge"
    }

    resource_labels = {
      project = "gcp-template-forge"
    }

    # Add GPU driver installation via daemonset or similar is handled by GKE
    # but we ensure the node config supports it.
  }
}
