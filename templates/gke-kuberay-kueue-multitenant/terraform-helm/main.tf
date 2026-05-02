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

locals {
  template_name = var.uid_suffix != "" ? "ray-kueue-multi-${var.uid_suffix}" : "ray-kueue-multi"
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

# Subnet with secondary ranges for VPC-native GKE
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

# GKE Standard Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  deletion_protection = false

  resource_labels = {
    project  = "gcp-template-forge"
    template = local.template_name
  }

  # Remove default node pool; managed separately below
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

  # Enable Dataplane V2 for network policies
  datapath_provider = "ADVANCED_DATAPATH"

  # Enable GKE addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

# System Node Pool for operators and non-GPU workloads
resource "google_container_node_pool" "system_pool" {
  name       = "system-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    spot         = true
    machine_type = "e2-standard-4"
    disk_size_gb = 50
    disk_type    = "pd-balanced"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    service_account = var.service_account

    labels = {
      project  = "gcp-template-forge"
      template = local.template_name
    }

    resource_labels = {
      project  = "gcp-template-forge"
      template = local.template_name
    }
  }
}

# GPU Node Pool for Ray workers
resource "google_container_node_pool" "gpu_pool" {
  name     = "gpu-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name

  # Use autoscaling for GPUs
  autoscaling {
    min_node_count = 0
    max_node_count = 5
  }

  initial_node_count = 0

  node_config {
    spot         = true
    machine_type = "n1-standard-4"
    disk_size_gb = 100
    disk_type    = "pd-balanced"

    guest_accelerator {
      type  = "nvidia-tesla-t4"
      count = 1
      gpu_sharing_config {
        gpu_sharing_strategy       = "TIME_SHARING"
        max_shared_clients_per_gpu = 4
      }
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    service_account = var.service_account

    labels = {
      project          = "gcp-template-forge"
      template         = local.template_name
      "nvidia.com/gpu" = "present"
    }

    resource_labels = {
      project  = "gcp-template-forge"
      template = local.template_name
    }

    taint {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NO_SCHEDULE"
    }
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
  templateName = local.template_name
  projectID    = var.project_id
})}
EOF
}
