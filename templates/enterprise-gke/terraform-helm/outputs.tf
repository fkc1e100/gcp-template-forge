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

output "cluster_endpoint" {
  description = "The endpoint of the GKE cluster"
  value       = google_container_cluster.enterprise_cluster.endpoint
}

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.enterprise_cluster.name
}

output "cluster_location" {
  description = "The location of the GKE cluster"
  value       = google_container_cluster.enterprise_cluster.location
}

output "vpc_name" {
  description = "The name of the VPC"
  value       = google_compute_network.vpc.name
}

output "workload_service_account_email" {
  description = "The email of the GCP Service Account for Workload Identity"
  value       = var.create_service_accounts ? google_service_account.workload_sa[0].email : (var.workload_service_account != "" ? var.workload_service_account : var.service_account)
}
