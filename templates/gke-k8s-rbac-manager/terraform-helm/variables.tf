variable "project_id" {
  type        = string
  description = "The GCP Project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "The GCP Region"
}

variable "cluster_name" {
  type        = string
  description = "The GKE Cluster name"
}

variable "network_name" {
  type        = string
  description = "The VPC Network name"
}

variable "subnet_name" {
  type        = string
  description = "The Subnet name"
}
