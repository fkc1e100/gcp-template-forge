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
  description = "The region to deploy the cluster"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The name of the cluster"
  type        = string
  default     = "latest-gke-features-tf"
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
  default     = "latest-gke-features-tf-vpc"
}

variable "subnet_name" {
  description = "The name of the subnet"
  type        = string
  default     = "latest-gke-features-tf-subnet"
}

variable "oauth_scopes" {
  description = "The set of Google API scopes to be made available on all of the node VMs"
  type        = list(string)
  default = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]
}

variable "service_account" {
  description = "The service account email to use for the node pool"
  type        = string
}
