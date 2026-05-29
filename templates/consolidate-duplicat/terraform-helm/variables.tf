variable "project_id" {
  type        = string
  description = "The GCP Project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "GCP Region"
}

variable "zone" {
  type        = string
  default     = "us-central1-a"
  description = "GCP Zone"
}

variable "cluster_name" {
  type        = string
  description = "GKE Cluster Name (CI provided)"
}

variable "network_name" {
  type        = string
  description = "VPC Network Name (CI provided)"
}

variable "subnet_name" {
  type        = string
  description = "Subnet Name (CI provided)"
}

variable "uid_suffix" {
  type        = string
  description = "Unique identifier suffix"
}

variable "service_account" {
  type        = string
  description = "Service Account for GCP/WIF"
}
