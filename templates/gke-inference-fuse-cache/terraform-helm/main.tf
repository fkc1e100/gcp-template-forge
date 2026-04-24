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
  uid            = var.uid_suffix != "" ? var.uid_suffix : random_id.bucket_suffix.hex
  base_name      = "gke-inf-fuse-cache"
  template_label = var.uid_suffix != "" ? "gke-inference-fuse-cache-${var.uid_suffix}" : "gke-inference-fuse-cache"
  ksa_name       = "${local.base_name}-${local.uid}-sa"
  bucket_name    = "${local.base_name}-tf-${local.uid}-bucket"
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name                     = var.subnet_name
  ip_cidr_range            = "10.10.0.0/20"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
  project                  = var.project_id

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
  project       = var.project_id
  force_destroy = true

  uniform_bucket_level_access = true

  labels = {
    project  = "gcp-template-forge"
    template = local.template_label
  }
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  provider = google-beta
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Restrict to zones that support L4 GPUs
  node_locations = ["${var.region}-a", "${var.region}-b", "${var.region}-c"]

  deletion_protection = false

  resource_labels = {
    project  = "gcp-template-forge"
    template = local.template_label
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
    create = "45m"
    update = "45m"
    delete = "45m"
  }
}

# GPU Node Pool with Local SSD
resource "google_container_node_pool" "gpu_pool" {
  provider = google-beta
  name     = "l4-gpu-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  # Use autoscaling to allow GKE to pick a zone with availability while keeping total node count low
  autoscaling {
    total_min_node_count = 0
    total_max_node_count = 1
    location_policy      = "BALANCED"
  }

  # Restrict to zones that support L4 GPUs
  node_locations = ["${var.region}-a", "${var.region}-b", "${var.region}-c"]

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
      "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    service_account = var.service_account

    labels = {
      project  = "gcp-template-forge"
      template = local.template_label
      gpu      = "l4"
    }

    resource_labels = {
      project  = "gcp-template-forge"
      template = local.template_label
    }
  }

  timeouts {
    create = "45m"
    update = "45m"
    delete = "45m"
  }
}

# System Node Pool for non-GPU workloads (e.g. model staging)
resource "google_container_node_pool" "system_pool" {
  name       = "system-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  project    = var.project_id
  node_count = 1

  # Use a single zone for the system pool to conserve quota in CI
  node_locations = ["${var.region}-a"]

  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 50
    disk_type    = "pd-balanced"

    service_account = var.service_account

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      project  = "gcp-template-forge"
      template = local.template_label
    }

    resource_labels = {
      project  = "gcp-template-forge"
      template = local.template_label
    }
  }

  timeouts {
    create = "45m"
    update = "45m"
    delete = "45m"
  }
}

# Generate values.yaml for the Helm chart
resource "local_file" "helm_values" {
  filename = "${path.module}/workload/values.yaml"
  content = <<-EOF
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the \"License\");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an \"AS IS\" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

${yamlencode({
  templateName = local.template_label
  bucketName   = google_storage_bucket.model_bucket.name
  serviceAccount = {
    name = local.ksa_name
  }
  # Default values for vllm-inference
  replicaCount = 1
  image = {
    repository = "google/cloud-sdk"
    tag        = "slim"
    pullPolicy = "IfNotPresent"
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

# Grant Bucket Access directly to the Kubernetes Service Account
# This uses Workload Identity to grant permissions to the KSA without needing a GSA,
# which avoids IAM permission issues for the builder service account in CI.
resource "google_storage_bucket_iam_member" "workload_sa_bucket_access" {
  bucket = google_storage_bucket.model_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.project_id}.svc.id.goog[default/${local.ksa_name}]"
}
