variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region to deploy to"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
}

variable "subnet_name" {
  description = "The name of the subnetwork"
  type        = string
}

variable "uid_suffix" {
  description = "A unique suffix for resource naming to prevent collisions"
  type        = string
}

variable "service_account" {
  description = "The service account to use for GKE nodes"
  type        = string
  default     = "default"
}
