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

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false

  # MANDATORY for project tracking
  project = var.project_id
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  ip_cidr_range = "10.0.0.0/20"
  region        = var.region
  network       = google_compute_network.vpc.id

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.4.0.0/14"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.8.0.0/20"
  }

  # MANDATORY for project tracking
  project = var.project_id
}

# Cloud NAT
resource "google_compute_router" "router" {
  name    = "${var.cluster_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
  project = var.project_id
}

resource "google_compute_router_nat" "nat" {
  name   = "${var.cluster_name}-nat"
  router = google_compute_router.router.name
  region = var.region

  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# GKE Cluster
resource "google_container_cluster" "cluster" {
  provider = google-beta
  name     = var.cluster_name
  location = var.region

  # MANDATORY for CI
  deletion_protection = false

  resource_labels = {
    project  = "gcp-template-forge"
    template = "gke-fqdn-egress-security"
  }

  network         = google_compute_network.vpc.name
  subnetwork      = google_compute_subnetwork.subnet.name
  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  remove_default_node_pool = true
  initial_node_count       = 1

  # Dataplane V2 is required for FQDN Network Policies
  datapath_provider          = "ADVANCED_DATAPATH"
  enable_fqdn_network_policy = true

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.32/28"
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

  release_channel {
    channel = "REGULAR"
  }

  # Enable GKE Enterprise features
  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_ENTERPRISE"
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  provider = google-beta
  name     = "fqdn-egress-pool"
  location = var.region
  cluster  = google_container_cluster.cluster.name

  node_count = 1

  node_config {
    spot         = true
    machine_type = "e2-standard-4"
    disk_size_gb = 50

    service_account = var.service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      project  = "gcp-template-forge"
      template = "gke-fqdn-egress-security"
    }

    resource_labels = {
      project  = "gcp-template-forge"
      template = "gke-fqdn-egress-security"
    }
  }
}

# Generate values.yaml for the Helm chart
resource "local_file" "helm_values" {
  content = <<EOF
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
  project_id = var.project_id
  pod = {
    image = "curlimages/curl:8.4.0"
    label = "egress-test"
  }
})}
EOF
  filename = "${path.module}/workload/values.yaml"
}

