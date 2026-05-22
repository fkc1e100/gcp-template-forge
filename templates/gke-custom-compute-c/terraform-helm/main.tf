terraform {
  required_version = ">= 1.3"
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
  # Do not add labels to subnet!
}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  enable_shielded_nodes    = true
  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = google_compute_network.vpc.id
  subnetwork               = google_compute_subnetwork.subnet.id

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = ""
    services_ipv4_cidr_block = ""
  }

  deletion_protection = false

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

resource "google_container_node_pool" "custom_compute" {
  name       = "custom-compute-pool"
  cluster    = google_container_cluster.primary.id
  location   = var.region
  node_count = 1

  node_locations = [var.zone]

  node_config {
    machine_type    = "custom-4-16384" # Custom machine type with 4 vCPUs and 16GB RAM
    service_account = var.service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      "compute-class" = "custom"
      "uid-suffix"    = var.uid_suffix
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}
