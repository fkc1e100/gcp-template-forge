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

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  # Remove default node pool; managed separately below
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = "default"
  subnetwork = "default"

  deletion_protection = false

  resource_labels = {
    project  = "gcp-template-forge"
    template = "gke-spot"
  }

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    use_ip_masquerade_as_nat = true
  }
  
  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

resource "google_container_node_pool" "spot_nodes" {
  name       = "spot-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_locations = [
    "${var.region}-a",
    "${var.region}-b",
    "${var.region}-c",
  ]

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    spot         = true
    machine_type = "e2-medium"

    service_account = var.service_account
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      project = "gcp-template-forge"
    }

    resource_labels = {
      project  = "gcp-template-forge"
      template = "gke-spot"
    }
  }
}

resource "google_container_node_pool" "standard_nodes" {
  name       = "standard-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_locations = [
    "${var.region}-a",
    "${var.region}-b",
    "${var.region}-c",
  ]

  node_config {
    machine_type = "e2-medium"
    
    service_account = var.service_account
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      project = "gcp-template-forge"
    }

    resource_labels = {
      project  = "gcp-template-forge"
      template = "gke-spot"
    }
  }
}
