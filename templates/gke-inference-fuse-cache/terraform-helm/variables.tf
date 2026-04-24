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

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region to deploy to"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The zone to deploy to (must support L4 GPUs)"
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "gke-inf-fuse-cache"
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
  default     = "gke-inf-fuse-cache-vpc"
}

variable "subnet_name" {
  description = "The name of the subnet"
  type        = string
  default     = "gke-inf-fuse-cache-sub"
}

variable "service_account" {
  description = "The service account to use for the node pool"
  type        = string
}

variable "uid_suffix" {
  description = "A unique suffix for resource identification in shared environments"
  type        = string
  default     = ""
}
