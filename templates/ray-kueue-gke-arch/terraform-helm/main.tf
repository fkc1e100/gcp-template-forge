provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.0.0.0/16"
}

resource "google_container_cluster" "primary" {
  name                     = var.cluster_name
  location                 = var.region
  network                  = google_compute_network.vpc.id
  subnetwork               = google_compute_subnetwork.subnet.id
  deletion_protection      = false
  initial_node_count       = 1
  remove_default_node_pool = true

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  addons_config {
    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

resource "google_container_node_pool" "system_pool" {
  name           = "system-pool"
  cluster        = google_container_cluster.primary.name
  location       = var.region
  node_locations = [var.zone]
  node_count     = 1

  node_config {
    machine_type = "e2-standard-4"
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

resource "google_container_node_pool" "ray_pool" {
  name           = "ray-pool"
  cluster        = google_container_cluster.primary.name
  location       = var.region
  node_locations = [var.zone]

  autoscaling {
    min_node_count = 0
    max_node_count = 3
  }

  queued_provisioning {
    enabled = true
  }

  node_config {
    machine_type = "e2-standard-8"
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    labels = {
      "ray-node-type" = "worker"
    }
  }
}
