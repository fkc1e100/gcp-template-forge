variable "project_id" {
  type        = string
  description = "The GCP project ID to deploy into"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "The GCP region"
}

variable "zone" {
  type        = string
  default     = "us-central1-a"
  description = "The GCP zone"
}

variable "cluster_name" {
  type        = string
  description = "The GKE cluster name"
}

variable "network_name" {
  type        = string
  description = "The VPC network name"
}

variable "subnet_name" {
  type        = string
  description = "The subnetwork name"
}

variable "uid_suffix" {
  type        = string
  description = "Suffix for resource uniqueness"
}

variable "service_account" {
  type        = string
  description = "Service account for the GKE nodes"
}
