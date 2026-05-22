variable "project_id" {
  type        = string
  description = "The GCP Project ID"
}

variable "region" {
  type        = string
  description = "The GCP Region"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "The GCP Zone"
  default     = "us-central1-a"
}

variable "cluster_name" {
  type        = string
  description = "The name of the GKE cluster"
}

variable "network_name" {
  type        = string
  description = "The VPC network name"
}

variable "subnet_name" {
  type        = string
  description = "The subnet name"
}

variable "uid_suffix" {
  type        = string
  description = "The last 6 digits of the CI run ID"
}

variable "service_account" {
  type        = string
  description = "The CI WIF service account"
}
