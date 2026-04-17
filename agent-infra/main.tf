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
  project = "gca-gke-2025"
  region  = "us-central1"
}

# VPC Network
resource "google_compute_network" "forge_network" {
  name                    = "forge-network"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "forge_subnet" {
  name          = "forge-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = "us-central1"
  network       = google_compute_network.forge_network.id
}

# GKE Standard Cluster
resource "google_container_cluster" "template_forge_cluster" {
  name     = "gcp-template-forge"
  location = "us-central1"

  # MANDATORY for CI/CD environments
  deletion_protection = false

  resource_labels = {
    project = "gcp-template-forge"
  }

  # We need Standard to support privileged pods for security scanning
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.forge_network.name
  subnetwork = google_compute_subnetwork.forge_subnet.name

  release_channel {
    channel = "REGULAR"
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

# Node Pool for Standard Cluster
resource "google_container_node_pool" "primary_nodes" {
  name     = "default-pool"
  location = "us-central1"
  cluster  = google_container_cluster.template_forge_cluster.name

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    preemptible  = false
    machine_type = "e2-standard-4"

    service_account = google_service_account.forge_builder.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

# Google Service Account
resource "google_service_account" "forge_builder" {
  account_id   = "forge-builder"
  display_name = "Forge Builder SA"
}

# IAM Bindings
locals {
  roles = [
    "roles/container.admin",
    "roles/compute.networkAdmin",
    "roles/gkehub.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/secretmanager.secretAccessor",
  ]
}

resource "google_project_iam_member" "forge_builder_bindings" {
  for_each = toset(local.roles)
  project  = "gca-gke-2025"
  role     = each.key
  member   = "serviceAccount:${google_service_account.forge_builder.email}"
}

# GCS Bucket for Validation Test State
resource "google_storage_bucket" "validation_tf_state" {
  name     = "gke-gca-2025-forge-tf-state"
  location = "US"
  versioning {
    enabled = true
  }
}
