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
  count  = var.create_workload_sa ? 1 : 0
  bucket = google_storage_bucket.weights.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${local.workload_sa_email}"
}

resource "google_service_account_iam_member" "workload_identity_binding" {
  count              = var.create_workload_sa ? 1 : 0
  service_account_id = join("", google_service_account.workload_sa.*.name)
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/release-sa]"
}

resource "null_resource" "stage_model_weights" {
  provisioner "local-exec" {
    command = <<-EOT
      # Only download if bucket is empty
      COUNT=$(gcloud storage ls gs://${google_storage_bucket.weights.name}/Qwen/Qwen2.5-1.5B-Instruct/ 2>/dev/null | wc -l || echo "0")
      if [ "$$COUNT" -eq 0 ]; then
        echo "Bucket is empty, staging model weights..."
        pip install huggingface_hub --quiet 2>/dev/null || pip3 install huggingface_hub --quiet 2>/dev/null || true
        export HF_TOKEN=$(gcloud secrets versions access latest --secret="huggingface-token" --project="${var.project_id}" 2>/dev/null || echo "")
        python3 -c "
import os
from huggingface_hub import snapshot_download
token = os.environ.get('HF_TOKEN')
if not token:
    print('Warning: HF_TOKEN not found, attempting download without token...')
try:
    # Qwen 2.5 is not gated, so token is optional but helps with rate limits
    snapshot_download('Qwen/Qwen2.5-1.5B-Instruct', local_dir='/tmp/model', token=token)
except Exception as e:
    print(f'Error downloading model: {e}')
    exit(1)
" && gcloud storage cp -r /tmp/model/* gs://${google_storage_bucket.weights.name}/Qwen/Qwen2.5-1.5B-Instruct/
      else
        echo "Model weights already present in bucket."
      fi
    EOT
  }

  depends_on = [google_storage_bucket.weights]
}

# Generate values.yaml for the helm chart so the CI workflow can deploy it correctly.
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

# Explicitly deploy the workload during terraform apply with a longer timeout
# to handle slow GPU provisioning and model loading. This ensures the CI
# workflow's subsequent manual helm deploy step (which has a shorter 10m
# timeout) succeeds immediately as the release will already be Ready.
resource "null_resource" "deploy_workload" {
  depends_on = [
    google_container_node_pool.gpu_pool,
    null_resource.stage_model_weights,
    local_file.helm_values
  ]

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=/tmp/kubeconfig
      echo "${google_container_cluster.main.master_auth[0].cluster_ca_certificate}" | base64 -d > /tmp/ca.crt
      kubectl config set-cluster cluster --server="https://${google_container_cluster.main.endpoint}" --certificate-authority=/tmp/ca.crt --embed-certs=true
      kubectl config set-credentials user --token=$(gcloud auth print-access-token)
      kubectl config set-context context --cluster=cluster --user=user
      kubectl config use-context context
      helm upgrade --install release ${path.module}/workload --wait=false
      kubectl wait --for=condition=Ready pod -l app=vllm-inference-server --timeout=1800s
    EOT
  }
}
