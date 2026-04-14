provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}


# VPC Network
resource "google_compute_network" "main" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name                     = var.subnet_name
  ip_cidr_range            = "10.32.0.0/20"
  region                   = var.region
  network                  = google_compute_network.main.id
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

resource "google_compute_router" "router" {
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_container_cluster" "main" {
  name                     = var.cluster_name
  location                 = var.region
  network                  = google_compute_network.main.name
  subnetwork               = google_compute_subnetwork.main.name
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  addons_config {
    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  # Use BASIC vulnerability mode for sandbox compatibility
  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }
}

resource "google_container_node_pool" "cpu_pool" {
  name       = "cpu-pool"
  location   = var.region
  cluster    = google_container_cluster.main.name
  node_count = 1

  node_config {
    machine_type    = "e2-standard-4"
    spot            = true
    service_account = var.service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

resource "google_container_node_pool" "gpu_pool" {
  name     = "gpu-pool"
  location = var.region
  cluster  = google_container_cluster.main.name

  # DWS Flex-Start requires autoscaling
  autoscaling {
    min_node_count = 0
    max_node_count = 1
  }

  queued_provisioning {
    enabled = true
  }

  node_config {
    machine_type = "g2-standard-12"
    spot         = false # DWS Flex-Start is NOT spot

    # DWS cannot use reservations
    reservation_affinity {
      consume_reservation_type = "NO_RESERVATION"
    }

    service_account = var.service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # L4 GPUs
    guest_accelerator {
      type  = "nvidia-l4"
      count = 1
    }

    # Important for GCS FUSE
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  # Restrict to us-central1-c as per GEMINI.md recommendation for L4
  node_locations = ["${var.region}-c"]
}

resource "google_storage_bucket" "weights" {
  name                        = "${var.project_id}-${var.cluster_name}-weights"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true
}

locals {
  workload_sa_email = var.workload_service_account_email != "" ? var.workload_service_account_email : var.service_account
}

resource "google_storage_bucket_iam_member" "workload_admin" {
  bucket = google_storage_bucket.weights.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${local.workload_sa_email}"
}

resource "null_resource" "cluster_credentials" {
  depends_on = [google_container_node_pool.cpu_pool]
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --region ${var.region} --project ${var.project_id}"
  }
}

# Generate values.yaml for the helm chart so the CI workflow can deploy it correctly.
# This file is ignored by git to avoid dirty working tree issues.
resource "local_file" "helm_values" {
  filename = "${path.module}/workload/values.yaml"
  content  = <<-EOT
replicaCount: 1

image:
  repository: vllm/vllm-openai
  tag: v0.7.2
  pullPolicy: IfNotPresent

serviceAccountEmail: ${local.workload_sa_email}

model:
  id: Qwen/Qwen2.5-1.5B-Instruct
  bucketName: ${google_storage_bucket.weights.name}

service:
  type: LoadBalancer
  port: 80

resources:
  limits:
    nvidia.com/gpu: 1
  requests:
    nvidia.com/gpu: 1

nodeSelector:
  cloud.google.com/gke-accelerator: nvidia-l4

tolerations:
- key: "nvidia.com/gpu"
  operator: "Exists"
  effect: "NoSchedule"
EOT
}

