variable "project_id" {
  type        = string
  description = "The GCP Project ID"
}

variable "region" {
  type        = string
  description = "The GCP region to deploy resources in"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "The GCP zone to deploy resources in"
  default     = "us-central1-a"
}

variable "cluster_name" {
  type        = string
  description = "The name of the GKE cluster"
}

variable "network_name" {
  type        = string
  description = "The name of the VPC network"
}

variable "subnet_name" {
  type        = string
  description = "The name of the subnet"
}

variable "uid_suffix" {
  type        = string
  description = "A unique suffix for resources under CI"
}

variable "service_account" {
  type        = string
  description = "The workflow/nodes service account"
}
