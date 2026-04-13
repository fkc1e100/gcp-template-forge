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
    host                   = "https://${google_container_cluster.main.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.main.master_auth[0].cluster_ca_certificate)
  }
}

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

locals {
  workload_sa_email = var.create_workload_sa ? join("", google_service_account.workload_sa.*.email) : (var.workload_service_account_email != "" ? var.workload_service_account_email : var.service_account)
}

resource "google_service_account" "workload_sa" {
  count        = var.create_workload_sa ? 1 : 0
  account_id   = "gke-llm-inference-workload"
  display_name = "GKE LLM Inference Workload Service Account"
}

resource "google_storage_bucket_iam_member" "workload_reader" {
  bucket = google_storage_bucket.weights.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${local.workload_sa_email}"
}

resource "google_service_account_iam_member" "workload_identity_binding" {
  count              = var.create_workload_sa ? 1 : 0
  service_account_id = join("", google_service_account.workload_sa.*.name)
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/${helm_release.release.name}-sa]"
}

resource "null_resource" "stage_model_weights" {
  provisioner "local-exec" {
    command = <<-EOT
      # Only download if bucket is empty
      COUNT=$(gsutil ls gs://${google_storage_bucket.weights.name}/google/gemma-2-2b-it/ 2>/dev/null | wc -l || echo "0")
      if [ "$COUNT" -eq 0 ]; then
        # Install huggingface_hub if needed, then download and copy
        pip install huggingface_hub --quiet 2>/dev/null || true
        python3 -c "
from huggingface_hub import snapshot_download
snapshot_download('google/gemma-2-2b-it', local_dir='/tmp/model')
" && gsutil -m cp -r /tmp/model/* gs://${google_storage_bucket.weights.name}/google/gemma-2-2b-it/
      fi
    EOT
  }

  depends_on = [google_storage_bucket.weights]
}

resource "helm_release" "release" {
  wait          = true
  wait_for_jobs = true
  timeout       = 3600
  name          = "release"
  chart         = "${path.module}/workload"
  namespace     = "default"

  set {
    name  = "bucketName"
    value = google_storage_bucket.weights.name
  }

  set {
    name  = "serviceAccountEmail"
    value = local.workload_sa_email
  }

  depends_on = [google_container_node_pool.gpu_pool, google_container_node_pool.cpu_pool, null_resource.stage_model_weights]
}
