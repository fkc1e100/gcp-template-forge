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
    host                   = "https://${google_container_cluster.enterprise_cluster.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.enterprise_cluster.master_auth[0].cluster_ca_certificate)
  }
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "vpc-issue-${var.issue_number}"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name                     = "subnet-issue-${var.issue_number}"
  ip_cidr_range            = "10.${var.issue_number}.0.0/20"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1${var.issue_number}.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "172.16.${var.issue_number}.0/20"
  }
}

resource "google_container_cluster" "enterprise_cluster" {
  name     = var.cluster_name
  location = var.region
  
  # MANDATORY for CI to be able to destroy
  deletion_protection = false

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
    master_ipv4_cidr_block  = "172.16.${var.issue_number + 100}.0/28"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
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

  secret_manager_config {
    enabled = true
  }

  release_channel {
    channel = "REGULAR"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "pool-issue-6"
  location   = var.region
  cluster    = google_container_cluster.enterprise_cluster.name
  node_count = 1 # Reducing for sandbox cost, was 3

  node_config {
    # Use spot/preemptible for sandbox
    spot = true
    
    machine_type = "e2-standard-4"
    disk_size_gb = 50
    disk_type    = "pd-standard"
    image_type   = "COS_CONTAINERD"

    service_account = var.service_account

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}

# Workload Service Account
resource "google_service_account" "workload_sa" {
  account_id   = "enterprise-workload-sa"
  display_name = "Enterprise Workload Service Account"
}

# Workload Identity binding
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.workload_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/enterprise-workload-sa]"
}

resource "helm_release" "workload" {
  name       = "enterprise-workload"
  chart      = "${path.module}/workload"
  namespace  = "default"
  depends_on = [google_container_node_pool.primary_nodes]

  values = [
    file("${path.module}/values.yaml")
  ]
}
