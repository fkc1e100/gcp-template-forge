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

resource "google_container_cluster" "main" {
  name                     = var.cluster_name
  location                 = var.region
  network                  = google_compute_network.main.name
  subnetwork               = google_compute_subnetwork.main.name
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  networking_mode          = "VPC_NATIVE"
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

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_ENTERPRISE"
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

  node_config {
    machine_type    = "g2-standard-12"
    spot            = false # DWS Flex-Start is NOT spot

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

  queued_provisioning {
    enabled = true
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

resource "google_service_account" "workload_sa" {
  account_id   = "gke-llm-inference-workload"
  display_name = "GKE LLM Inference Workload Service Account"
}

resource "google_storage_bucket_iam_member" "workload_reader" {
  bucket = google_storage_bucket.weights.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.workload_sa.email}"
}

resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.workload_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/gemma-2-2b-it-vllm-sa]"
}

resource "helm_release" "vllm" {
  name      = "vllm"
  chart     = "${path.module}/workload"
  namespace = "default"

  set {
    name  = "bucketName"
    value = google_storage_bucket.weights.name
  }

  set {
    name  = "serviceAccountEmail"
    value = google_service_account.workload_sa.email
  }

  depends_on = [google_container_node_pool.gpu_pool, google_service_account_iam_member.workload_identity_binding]
}
