provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name                     = var.subnet_name
  ip_cidr_range            = "10.0.0.0/20"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  remove_default_node_pool = true
  initial_node_count       = 1

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  deletion_protection = false
}

resource "google_container_node_pool" "custom_nodes" {
  name       = "custom-node-pool"
  cluster    = google_container_cluster.primary.id
  node_count = 1

  node_locations = [var.zone]

  node_config {
    preemptible  = false
    machine_type = "e2-custom-4-8192"

    service_account = var.service_account
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      "compute-class" = "custom-compute"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}
