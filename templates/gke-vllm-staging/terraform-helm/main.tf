terraform {
  backend "gcs" {}
  required_providers {
    google      = { source = "hashicorp/google", version = "~> 6.0" }
    google-beta = { source = "hashicorp/google-beta", version = "~> 6.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# --- VPC ---
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-tf-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name                     = "${var.cluster_name}-tf-subnet"
  ip_cidr_range            = "10.48.0.0/20"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.52.0.0/14"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.56.0.0/20"
  }
}

# --- GKE Cluster ---
resource "google_container_cluster" "main" {
  name     = "${var.cluster_name}-tf"
  location = var.region

  networking_mode = "VPC_NATIVE"
  network         = google_compute_network.vpc.self_link
  subnetwork      = google_compute_subnetwork.subnet.self_link

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  addons_config {
    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_ENTERPRISE"
  }

  resource_labels = {
    project = "gcp-template-forge"
  }
}

# --- CPU Node Pool ---
resource "google_container_node_pool" "cpu_pool" {
  name       = "cpu-pool"
  location   = var.region
  cluster    = google_container_cluster.main.name
  node_count = 1

  node_config {
    machine_type = "e2-standard-4"
    spot         = true
    service_account = var.service_account
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

# --- GPU Node Pool (DWS Flex-Start) ---
resource "google_container_node_pool" "gpu_pool" {
  name     = "gpu-pool"
  location = var.region
  cluster  = google_container_cluster.main.name

  autoscaling {
    min_node_count = 0
    max_node_count = 1
  }

  queued_provisioning {
    enabled = true
  }

  node_config {
    machine_type = "g2-standard-12"
    spot         = false

    reservation_affinity {
      consume_reservation_type = "NO_RESERVATION"
    }

    guest_accelerator {
      type  = "nvidia-l4"
      count = 1
    }

    service_account = var.service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      "cloud.google.com/gke-accelerator" = "nvidia-l4"
    }
  }

  node_locations = ["${var.region}-c"]
}

# --- GCS Bucket for Weights ---
resource "google_storage_bucket" "weights" {
  name                        = "${var.project_id}-${var.cluster_name}-weights-tf"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  labels = {
    project = "gcp-template-forge"
  }
}

resource "google_storage_bucket_iam_member" "workload_sa_reader" {
  bucket = google_storage_bucket.weights.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.service_account}"
}
