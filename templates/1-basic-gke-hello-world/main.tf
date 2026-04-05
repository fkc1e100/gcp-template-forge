provider "google" {
  project = var.project_id
  region  = var.region
}

# VPC Network
resource "google_compute_network" "hello_world_network" {
  name                    = "${var.cluster_name}-network"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "hello_world_subnet" {
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.hello_world_network.id
}

# GKE Cluster
resource "google_container_cluster" "hello_world_cluster" {
  name     = var.cluster_name
  location = var.region

  # We'll use a separate node pool for better control
  remove_default_node_pool = true
  initial_node_count       = 1

  network          = google_compute_network.hello_world_network.name
  subnetwork       = google_compute_subnetwork.hello_world_subnet.name

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = ""
    services_ipv4_cidr_block = ""
  }
}

# Node Pool
resource "google_container_node_pool" "hello_world_nodes" {
  name       = "default-pool"
  location   = var.region
  cluster    = google_container_cluster.hello_world_cluster.name
  
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
