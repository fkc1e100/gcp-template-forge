# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "gke-llm-inference-gemma-tf-vpc"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name                     = "gke-llm-inference-gemma-tf-subnet"
  ip_cidr_range            = "10.32.0.0/20"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.36.0.0/14"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.40.0.0/20"
  }
}

# Cloud NAT for private nodes
resource "google_compute_router" "router" {
  name    = "gke-llm-inference-gemma-tf-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "gke-llm-inference-gemma-tf-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# GCS Bucket for model weights
resource "google_storage_bucket" "weights" {
  name                        = "${var.project_id}-gemma-weights-tf"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  # MANDATORY for CI to be able to destroy
  deletion_protection = false

  resource_labels = {
    "template" = "gke-llm-inference-gemma"
  }

  remove_default_node_pool = true
  initial_node_count       = 1

  networking_mode = "VPC_NATIVE"
  network         = google_compute_network.vpc.name
  subnetwork      = google_compute_subnetwork.subnet.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "10.44.0.0/28"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_ENTERPRISE"
  }

  release_channel {
    channel = "RAPID"
  }
}

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
    spot            = false
    machine_type    = "g2-standard-12"

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
      "template"       = "gke-llm-inference-gemma"
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

# IAM for GCS FUSE and Workload Identity using existing service account
resource "google_storage_bucket_iam_member" "weights_viewer" {
  bucket = google_storage_bucket.weights.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.service_account}"
}

# Helm Release
resource "helm_release" "workload" {
  name             = "gke-llm-inference-gemma"
  chart            = "${path.module}/workload"
  namespace        = "gemma"
  create_namespace = true
  depends_on       = [google_container_node_pool.gpu_pool]

  values = [
    file("${path.module}/workload/values.yaml")
  ]

  set {
    name  = "bucketName"
    value = google_storage_bucket.weights.name
  }

  set {
    name  = "serviceAccount.annotations.iam\\.gke\\.io/gcp-service-account"
    value = var.service_account
  }
}

