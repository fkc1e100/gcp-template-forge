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

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  uid                = var.uid_suffix != "" ? var.uid_suffix : random_id.bucket_suffix.hex
  workload_gsa_email = var.service_account
  ksa_name           = "gke-inf-fuse-cache-${local.uid}-sa"
  # Use a unique bucket name that matches the CI re-calculation
  bucket_name = "gke-inf-fuse-cache-tf-${local.uid}-bucket"
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name                     = var.subnet_name
  ip_cidr_range            = "10.10.0.0/20"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.11.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.12.0.0/20"
  }
}

# GCS Bucket for models
resource "google_storage_bucket" "model_bucket" {
  name          = local.bucket_name
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true

  labels = {
    project  = "gcp-template-forge"
    template = var.uid_suffix != "" ? "gke-inf-fuse-cache-${var.uid_suffix}" : "gke-inf-fuse-cache"
  }
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  provider = google-beta
  name     = var.cluster_name
  location = var.region

  deletion_protection = false

  resource_labels = {
    project  = "gcp-template-forge"
    template = var.uid_suffix != "" ? "gke-inf-fuse-cache-${var.uid_suffix}" : "gke-inf-fuse-cache"
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

  # Enable GCS FUSE CSI Driver
  addons_config {
    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

# GPU Node Pool with Local SSD
resource "google_container_node_pool" "gpu_pool" {
  provider   = google-beta
  name       = "l4-gpu-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_locations = [
    "${var.region}-a",
    "${var.region}-b",
    "${var.region}-c",
  ]

  node_config {
    # Use on-demand instances for better availability (spot can be harder to find in some zones)
    spot = false

    machine_type = "g2-standard-4"
    disk_size_gb = 50
    disk_type    = "pd-balanced"

    # G2-standard-4 has 1 x L4 GPU
    guest_accelerator {
      type  = "nvidia-l4"
      count = 1

      # Automatically install NVIDIA GPU drivers
      gpu_driver_installation_config {
        gpu_driver_version = "DEFAULT"
      }
    }

    # Attach Local SSD for GCS FUSE caching
    ephemeral_storage_local_ssd_config {
      local_ssd_count = 1
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    service_account = var.service_account

    labels = {
      project  = "gcp-template-forge"
      template = var.uid_suffix != "" ? "gke-inf-fuse-cache-${var.uid_suffix}" : "gke-inf-fuse-cache"
      gpu      = "l4"
    }

    resource_labels = {
      project  = "gcp-template-forge"
      template = var.uid_suffix != "" ? "gke-inf-fuse-cache-${var.uid_suffix}" : "gke-inf-fuse-cache"
    }
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

# System Node Pool for non-GPU workloads (e.g. model staging)
resource "google_container_node_pool" "system_pool" {
  name       = "system-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_locations = [
    "${var.region}-a",
    "${var.region}-b",
    "${var.region}-c",
  ]

  node_config {
    machine_type = "e2-standard-2"
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
      template = var.uid_suffix != "" ? "gke-inf-fuse-cache-${var.uid_suffix}" : "gke-inf-fuse-cache"
    }

    resource_labels = {
      project  = "gcp-template-forge"
      template = var.uid_suffix != "" ? "gke-inf-fuse-cache-${var.uid_suffix}" : "gke-inf-fuse-cache"
    }
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

# IAM for Workload Identity
# Grant the Kubernetes Service Account direct permissions on the bucket.
# This avoids the need for the KSA to impersonate a GSA, which can be
# problematic in some CI environments. This is a resource-level binding.
resource "google_storage_bucket_iam_member" "bucket_admin_ksa" {
  bucket = google_storage_bucket.model_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.project_id}.svc.id.goog[default/${local.ksa_name}]"
}

# Also grant permissions to the node's GSA as a fallback (optional but helps robustness)
resource "google_storage_bucket_iam_member" "bucket_admin_gsa" {
  bucket = google_storage_bucket.model_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.service_account}"
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
  templateName           = var.uid_suffix != "" ? "gke-inf-fuse-cache-${var.uid_suffix}" : "gke-inf-fuse-cache"
  bucketName             = google_storage_bucket.model_bucket.name
  gcpServiceAccountEmail = ""
  serviceAccount = {
    name = local.ksa_name
  }
  # Default values for vllm-inference
  replicaCount = 1
  image = {
    repository = "google/cloud-sdk"
    tag        = "slim"
  }
  resources = {
    limits = {
      "nvidia.com/gpu" = 1
    }
    requests = {
      "nvidia.com/gpu" = 1
    }
  }
  nodeSelector = {
    gpu = "l4"
  }
  tolerations = [
    {
      key      = "nvidia.com/gpu"
      operator = "Exists"
      effect   = "NoSchedule"
    }
  ]
  cache = {
    capacity                = "50Gi"
    metadataCacheTTLSeconds = 3600
    statCacheCapacity       = "512Mi"
    typeCacheCapacity       = "64Mi"
  }
})}
EOF
}
