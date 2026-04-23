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
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name                     = var.subnet_name
  ip_cidr_range            = "10.16.0.0/20"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.20.0.0/14"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.24.0.0/20"
  }
}

# Cloud NAT for private nodes
resource "google_compute_router" "router" {
  name    = "${var.cluster_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.cluster_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_container_cluster" "enterprise_cluster" {
  provider = google-beta
  name     = var.cluster_name
  location = var.region

  # MANDATORY for CI to be able to destroy
  deletion_protection = false

  resource_labels = {
    project  = "gcp-template-forge"
    template = "enterprise-gke"
  }

  remove_default_node_pool = true
  initial_node_count       = 1

  networking_mode = "VPC_NATIVE"
  network         = google_compute_network.vpc.id
  subnetwork      = google_compute_subnetwork.subnet.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.1.0/28"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  master_authorized_networks_config {
    # In production, this should be restricted to known administrative CIDR ranges.
    # An empty list here with the config enabled effectively blocks all public access to the master.
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
    gcp_filestore_csi_driver_config {
      enabled = true
    }
  }

  secret_manager_config {
    enabled = true
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
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
    channel = "REGULAR"
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  provider   = google-beta
  name       = "enterprise-gke-pool"
  location   = var.region
  cluster    = google_container_cluster.enterprise_cluster.name
  node_count = 1

  node_config {
    # Use spot/preemptible for sandbox
    spot = true

    machine_type = "e2-standard-4"
    disk_size_gb = 50
    disk_type    = "pd-standard"
    image_type   = "COS_CONTAINERD"

    service_account = var.create_service_accounts ? google_service_account.node_sa[0].email : var.service_account

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      project  = "gcp-template-forge"
      template = "enterprise-gke"
    }

    resource_labels = {
      project  = "gcp-template-forge"
      template = "enterprise-gke"
    }
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}


# GCP Service Account for Workload Identity
resource "google_service_account" "workload_sa" {
  count        = var.create_service_accounts ? 1 : 0
  account_id   = replace(substr("wkld-${var.cluster_name}", 0, 30), "/-$/", "")
  display_name = "Enterprise Workload Service Account"
}

resource "google_service_account_iam_member" "workload_identity_binding" {
  for_each           = var.create_service_accounts ? toset(["default", "gke-workload"]) : []
  service_account_id = google_service_account.workload_sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value}/gke-workload-sa]"
}

# GCP Service Account for Nodes
resource "google_service_account" "node_sa" {
  count        = var.create_service_accounts ? 1 : 0
  account_id   = replace(substr("node-${var.cluster_name}", 0, 30), "/-$/", "")
  display_name = "Enterprise GKE Node Service Account"
}

resource "google_project_iam_member" "node_logging" {
  count   = var.create_service_accounts ? 1 : 0
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.node_sa[0].email}"
}

resource "google_project_iam_member" "node_monitoring_metric" {
  count   = var.create_service_accounts ? 1 : 0
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.node_sa[0].email}"
}

resource "google_project_iam_member" "node_metadata_writer" {
  count   = var.create_service_accounts ? 1 : 0
  project = var.project_id
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.node_sa[0].email}"
}

# Generate values.yaml for the Helm chart
resource "local_file" "helm_values" {
  filename = "${path.module}/workload/values.generated.yaml"
  content  = <<-EOF
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

replicaCount: 3

image:
  repository: nginxinc/nginx-unprivileged
  pullPolicy: IfNotPresent
  tag: "1.25.3"

serviceAccount:
  create: true
  name: "gke-workload-sa"
  gcpServiceAccount: "${var.create_service_accounts ? google_service_account.workload_sa[0].email : var.service_account}"

podSecurityContext:
  runAsUser: 1000
  runAsGroup: 3000
  fsGroup: 2000
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault

securityContext:
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false

service:
  type: LoadBalancer
  port: 80
  targetPort: 8080

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

pdb:
  enabled: true
  minAvailable: 2

networkPolicy:
  enabled: true

config:
  LOG_LEVEL: "info"
  ENVIRONMENT: "production"

secrets:
  enabled: false
  providerClass: "enterprise-gke-secrets"
  gcpProjectId: "${var.project_id}"
  secretName: "enterprise-gke-secret"
  secretVersion: "latest"
EOF
}
