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

provider "helm" {
  # Uses ~/.kube/config written by null_resource.cluster_credentials below.
  # Do not configure the kubernetes {} block with computed cluster attributes —
  # the endpoint is unknown during plan when the cluster is created from scratch,
  # causing "invalid configuration: no configuration has been provided".
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "basic-gke-tf-vpc"
  auto_create_subnetworks = false
}

# Subnet with secondary ranges for VPC-native GKE Autopilot
resource "google_compute_subnetwork" "subnet" {
  name          = "basic-gke-tf-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.4.0.0/14"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.8.0.0/20"
  }
}

# GKE Autopilot Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  deletion_protection = false

  enable_autopilot = true

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  release_channel {
    channel = "REGULAR"
  }

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }
}

# Configure kubectl after the cluster is ready; helm provider uses this kubeconfig.
resource "null_resource" "cluster_credentials" {
  depends_on = [google_container_cluster.primary]

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region} --project ${var.project_id}"
  }
}

# Hello World workload via Helm
resource "helm_release" "hello_world" {
  name             = "basic-gke"
  chart            = "${path.module}/workload"
  namespace        = "hello-world"
  create_namespace = true
  depends_on       = [null_resource.cluster_credentials]
}
