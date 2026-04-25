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

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.gke_inference_fuse_cache_cluster.name
}

output "cluster_endpoint" {
  description = "The IP address of the GKE cluster master"
  value       = google_container_cluster.gke_inference_fuse_cache_cluster.endpoint
  sensitive   = true
}

output "cluster_location" {
  description = "The location of the GKE cluster"
  value       = google_container_cluster.gke_inference_fuse_cache_cluster.location
}

output "region" {
  description = "The region where the resources are deployed"
  value       = var.region
}

output "bucket_name" {
  description = "The name of the GCS bucket used for model storage"
  value       = google_storage_bucket.model_bucket.name
}

output "ksa_name" {
  description = "The name of the Kubernetes Service Account"
  value       = local.ksa_name
}

output "vllm_service_name" {
  description = "The name of the vLLM inference service"
  value       = "vllm-inference"
}
