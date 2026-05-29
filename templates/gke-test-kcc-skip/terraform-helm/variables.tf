variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "GCP zone"
  default     = "us-central1-a"
}

variable "cluster_name" {
  type        = string
  description = "Cluster name"
}

variable "network_name" {
  type        = string
  description = "VPC network name"
}

variable "subnet_name" {
  type        = string
  description = "VPC subnet name"
}

variable "uid_suffix" {
  type        = string
  description = "UID suffix for uniqueness"
}

variable "service_account" {
  type        = string
  description = "CI WIF service account"
}
