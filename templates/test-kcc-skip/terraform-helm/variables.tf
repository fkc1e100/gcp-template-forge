variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "test-kcc-skip"
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
  default     = "test-kcc-skip-vpc"
}

variable "subnet_name" {
  description = "The name of the subnetwork"
  type        = string
  default     = "test-kcc-skip-subnet"
}

variable "service_account" {
  description = "The service account to use for the cluster"
  type        = string
}
