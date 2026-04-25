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
  template_label = var.uid_suffix != "" ? "gke-kuberay-kueue-multitenant-${var.uid_suffix}" : "gke-kuberay-kueue-multitenant"
}

# VPC Network
resource "google_compute_network" "gke_kuberay_kueue_multitenant_vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Subnet
resource "google_compute_subnetwork" "gke_kuberay_kueue_multitenant_subnet" {
  name                     = var.subnet_name
  ip_cidr_range            = "10.0.0.0/20"
  region                   = var.region
  network                  = google_compute_network.gke_kuberay_kueue_multitenant_vpc.id
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
resource "google_container_cluster" "gke_kuberay_kueue_multitenant_cluster" {
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

  network    = google_compute_network.gke_kuberay_kueue_multitenant_vpc.name
  subnetwork = google_compute_subnetwork.gke_kuberay_kueue_multitenant_subnet.name

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

# Dedicated Node Service Account for Least Privilege
# In restricted CI environments, we use the provided var.service_account instead.
resource "google_service_account" "node_sa" {
  count        = var.create_gsas ? 1 : 0
  account_id   = "gke-ray-mt-node-${var.uid_suffix}"
  display_name = "GKE Node Service Account for Multi-Tenant Ray"
  project      = var.project_id
}

resource "google_project_iam_member" "node_sa_logging" {
  count   = var.create_gsas ? 1 : 0
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.node_sa[0].email}"
}

resource "google_project_iam_member" "node_sa_monitoring" {
  count   = var.create_gsas ? 1 : 0
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.node_sa[0].email}"
}

resource "google_project_iam_member" "node_sa_registry" {
  count   = var.create_gsas ? 1 : 0
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.node_sa[0].email}"
}

locals {
  node_sa_email   = var.create_gsas ? google_service_account.node_sa[0].email : var.service_account
  team_a_sa_email = var.create_gsas ? google_service_account.team_a_sa[0].email : var.service_account
  team_b_sa_email = var.create_gsas ? google_service_account.team_b_sa[0].email : var.service_account
}

# Team GSAs for Workload Identity
resource "google_service_account" "team_a_sa" {
  count        = var.create_gsas ? 1 : 0
  account_id   = "ray-team-a-${var.uid_suffix}"
  display_name = "GSA for Ray Team A"
  project      = var.project_id
}

resource "google_service_account" "team_b_sa" {
  count        = var.create_gsas ? 1 : 0
  account_id   = "ray-team-b-${var.uid_suffix}"
  display_name = "GSA for Ray Team B"
  project      = var.project_id
}

# Workload Identity Bindings for Teams
resource "google_service_account_iam_member" "team_a_wi" {
  count              = var.create_gsas ? 1 : 0
  service_account_id = google_service_account.team_a_sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[team-a/team-a-sa]"
}

resource "google_service_account_iam_member" "team_b_wi" {
  count              = var.create_gsas ? 1 : 0
  service_account_id = google_service_account.team_b_sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[team-b/team-b-sa]"
}

# System Node Pool
resource "google_container_node_pool" "system_nodes" {
  name       = "gke-kuberay-kueue-multitenant-sys"
  location   = var.region
  cluster    = google_container_cluster.gke_kuberay_kueue_multitenant_cluster.name
  project    = var.project_id
  node_count = 2

  # Use a single zone for the system pool to conserve quota in CI
  node_locations = ["${var.region}-a"]

  node_config {
    spot         = false
    machine_type = "e2-standard-4"
    disk_size_gb = 50
    disk_type    = "pd-balanced" # Optimized performance per reviewer request

    service_account = local.node_sa_email
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only"
    ]

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
resource "google_container_node_pool" "gpu_nodes" {
  provider = google-beta
  name     = "gke-kuberay-kueue-multitenant-gpu"
  location = var.region
  cluster  = google_container_cluster.gke_kuberay_kueue_multitenant_cluster.name
  project  = var.project_id

  node_locations = [
    "${var.region}-a",
    "${var.region}-b",
    "${var.region}-c",
  ]

  autoscaling {
    total_min_node_count = 0
    total_max_node_count = 5
    location_policy      = "ANY"
  }

  node_config {
    spot         = false
    machine_type = "g2-standard-4"
    disk_size_gb = 100
    disk_type    = "pd-balanced" # Optimized performance for model caching

    service_account = local.node_sa_email
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only"
    ]

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

  depends_on = [google_container_cluster.gke_kuberay_kueue_multitenant_cluster]
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
  clusterName  = var.cluster_name
  projectID    = var.project_id
  region       = var.region
  uidSuffix    = var.uid_suffix
  teamASAEmail = var.create_gsas ? local.team_a_sa_email : ""
  teamBSAEmail = var.create_gsas ? local.team_b_sa_email : ""
})}
EOF
}
