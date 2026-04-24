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

locals {
  ksa_name       = "gke-inf-fuse-cache-${var.uid_suffix}-sa"
  template_label = var.uid_suffix != "" ? "gke-inference-fuse-cache-${var.uid_suffix}" : "gke-inference-fuse-cache"
}

# VPC Network
resource "google_compute_network" "gke_inference_fuse_cache_vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Subnet
resource "google_compute_subnetwork" "gke_inference_fuse_cache_subnet" {
  name                     = var.subnet_name
  ip_cidr_range            = "10.0.0.0/20"
  region                   = var.region
  network                  = google_compute_network.gke_inference_fuse_cache_vpc.id
  private_ip_google_access = true
  project                  = var.project_id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.4.0.0/14"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.8.0.0/20"
  }
}

# GKE Cluster
resource "google_container_cluster" "gke_inference_fuse_cache_cluster" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  deletion_protection = false

  resource_labels = {
    project  = "gcp-template-forge"
    template = local.template_label
  }

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.gke_inference_fuse_cache_vpc.name
  subnetwork = google_compute_subnetwork.gke_inference_fuse_cache_subnet.name

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

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  timeouts {
    create = "45m"
    update = "45m"
    delete = "45m"
  }
}

# System Node Pool
resource "google_container_node_pool" "system_pool" {
  name       = "gke-inf-fuse-cache-sys"
  location   = var.region
  cluster    = google_container_cluster.gke_inference_fuse_cache_cluster.name
  project    = var.project_id
  node_count = 1

  node_locations = ["${var.region}-a"]

  node_config {
    spot         = false
    machine_type = "e2-standard-4"
    disk_size_gb = 50
    disk_type    = "pd-balanced"

    service_account = var.service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      project  = "gcp-template-forge"
      template = local.template_label
      pool     = "system"
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

# GPU Node Pool (Autoscaled)
resource "google_container_node_pool" "gpu_pool" {
  provider = google-beta
  name     = "gke-inf-fuse-cache-gpu"
  location = var.region
  cluster  = google_container_cluster.gke_inference_fuse_cache_cluster.name
  project  = var.project_id

  node_locations = ["${var.region}-a"]

  autoscaling {
    total_min_node_count = 0
    total_max_node_count = 1 # Keep small for CI
    location_policy      = "BALANCED"
  }

  node_config {
    spot         = false
    machine_type = "g2-standard-4"
    disk_size_gb = 100
    disk_type    = "pd-balanced"

    service_account = var.service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    guest_accelerator {
      type  = "nvidia-l4"
      count = 1

      gpu_driver_installation_config {
        gpu_driver_version = "DEFAULT"
      }
    }

    labels = {
      project                            = "gcp-template-forge"
      template                           = local.template_label
      pool                               = "gpu"
      "cloud.google.com/gke-accelerator" = "nvidia-l4"
    }

    resource_labels = {
      project  = "gcp-template-forge"
      template = local.template_label
    }

    taint {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NO_SCHEDULE"
    }
  }

  timeouts {
    create = "45m"
    update = "45m"
    delete = "45m"
  }

  depends_on = [google_container_cluster.gke_inference_fuse_cache_cluster]
}

# Model Bucket
resource "google_storage_bucket" "model_bucket" {
  name          = "gke-inf-fuse-cache-tf-${var.uid_suffix}-bucket"
  location      = "US"
  force_destroy = true
  project       = var.project_id

  labels = {
    project  = "gcp-template-forge"
    template = local.template_label
  }
}

# IAM for Workload Identity
resource "google_storage_bucket_iam_member" "workload_sa_bucket_access" {
  bucket = google_storage_bucket.model_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.project_id}.svc.id.goog[default/${local.ksa_name}]"
}

# Generate values.yaml for Helm
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
  replicaCount = 1
  image = {
    repository = "rayproject/ray"
    tag        = "2.9.0"
    pullPolicy = "IfNotPresent"
  }
  resources = {
    limits = {
      cpu              = "2"
      memory           = "4Gi"
      "nvidia.com/gpu" = 1
    }
    requests = {
      cpu              = "2"
      memory           = "4Gi"
      "nvidia.com/gpu" = 1
    }
  }
  nodeSelector = {
    "cloud.google.com/gke-accelerator" = "nvidia-l4"
  }
  tolerations = [
    {
      key      = "nvidia.com/gpu"
      operator = "Exists"
      effect   = "NoSchedule"
    }
  ]
  bucketName = google_storage_bucket.model_bucket.name
  cache = {
    capacity                = "50Gi"
    metadataCacheTTLSeconds = "3600"
    statCacheCapacity       = "10000"
    typeCacheCapacity       = "10000"
  }
  serviceAccount = {
    create = true
    name   = local.ksa_name
  }
})}
EOF
}
