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

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  uid = var.uid_suffix != "" ? var.uid_suffix : random_id.suffix.hex
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name                     = var.subnet_name
  ip_cidr_range            = "10.0.0.0/20"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.4.0.0/14"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.8.0.0/20"
  }
}

# Cloud NAT for private nodes to pull images
resource "google_compute_router" "router" {
  name    = "ray-kueue-router-${local.uid}"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "ray-kueue-nat-${local.uid}"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

data "google_compute_zones" "available" {
  region = var.region
  status = "UP"
}

locals {
  zone = var.zone != "us-central1-a" ? var.zone : data.google_compute_zones.available.names[0]
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  provider = google-beta
  name     = var.cluster_name
  location = var.region

  # Restrict to a single zone for GPU availability and reliability
  node_locations = [local.zone]

  deletion_protection = false

  resource_labels = {
    project  = "gcp-template-forge"
    template = "ray-kueue"
  }

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }

  # Enable GKE Gateway API for potential UI access
  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

# System Node Pool
resource "google_container_node_pool" "system_pool" {
  name       = "system-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    spot         = true
    machine_type = "e2-standard-4" # Increased to handle operators
    disk_size_gb = 50
    disk_type    = "pd-balanced"

    service_account = var.service_account

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      project  = "gcp-template-forge"
      template = "ray-kueue"
    }

    resource_labels = {
      project  = "gcp-template-forge"
      template = "ray-kueue"
    }
  }
}

# GPU Node Pool (Autoscaled)
resource "google_container_node_pool" "gpu_pool" {
  provider = google-beta
  name     = "gpu-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name

  # Autoscaling configuration
  autoscaling {
    min_node_count  = 0
    max_node_count  = 10
    location_policy = "BALANCED"
  }

  node_config {
    spot = true # Use spot for cost efficiency in sandbox

    machine_type = "g2-standard-4" # 1 x L4 GPU
    disk_size_gb = 100
    disk_type    = "pd-balanced"

    guest_accelerator {
      type  = "nvidia-l4"
      count = 1
      gpu_driver_installation_config {
        gpu_driver_version = "DEFAULT"
      }
    }

    service_account = var.service_account

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      project  = "gcp-template-forge"
      template = "ray-kueue"
      gpu      = "l4"
    }

    taint {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NO_SCHEDULE"
    }

    resource_labels = {
      project  = "gcp-template-forge"
      template = "ray-kueue"
    }
  }

  # Ensure the node pool is not deleted if it's empty
  lifecycle {
    ignore_changes = [
      node_count
    ]
  }
}

# Generate values.yaml for the Helm chart
resource "local_file" "helm_values" {
  filename = "${path.module}/workload/values.yaml"
  content = <<-EOF
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

${yamlencode({
  projectID    = var.project_id
  region       = var.region
  clusterName  = google_container_cluster.primary.name
  templateName = "ray-kueue"

  # KubeRay Operator configuration
  kuberay-operator = {
    enabled = true
  }

  # Kueue configuration
  kueue = {
    enabled = true
  }

  # Multi-tenant configuration
  teams = [
    {
      name           = "team-a"
      nominalQuota   = 2
      borrowingLimit = 0
    },
    {
      name           = "team-b"
      nominalQuota   = 2
      borrowingLimit = 2
    }
  ]
})}
EOF
}
