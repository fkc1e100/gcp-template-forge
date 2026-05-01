variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "gca-gke-2025"
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "ray-kueue-tf-cluster-local"
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
  default     = "ray-kueue-tf-vpc-local"
}

variable "subnet_name" {
  description = "The name of the subnetwork"
  type        = string
  default     = "ray-kueue-tf-subnet-local"
}

variable "uid_suffix" {
  description = "UID suffix for unique naming"
  type        = string
  default     = "local"
}
