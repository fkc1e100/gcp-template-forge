variable "project_id" {
  type        = string
  description = "The GCP Project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "The region to deploy resources to"
}

variable "zone" {
  type        = string
  default     = "us-central1-a"
  description = "The zone to deploy the node pool to"
}

variable "cluster_name" {
  type        = string
  description = "The GKE cluster name (provided by CI)"
}

variable "network_name" {
  type        = string
  description = "The VPC network name (provided by CI)"
}

variable "subnet_name" {
  type        = string
  description = "The VPC subnetwork name (provided by CI)"
}

variable "uid_suffix" {
  type        = string
  description = "Unique identifier suffix (provided by CI)"
}

variable "service_account" {
  type        = string
  description = "The service account for Workload Identity / CI (provided by CI)"
}
