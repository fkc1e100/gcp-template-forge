variable "project_id" {
  type        = string
  description = "The GCP project ID to deploy resources into"
}

variable "region" {
  type        = string
  description = "The GCP region to deploy to"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "The GCP zone to deploy to"
  default     = "us-central1-a"
}

variable "cluster_name" {
  type        = string
  description = "The name of the GKE cluster (CI provided)"
}

variable "network_name" {
  type        = string
  description = "The name of the VPC network (CI provided)"
}

variable "subnet_name" {
  type        = string
  description = "The name of the subnet (CI provided)"
}

variable "uid_suffix" {
  type        = string
  description = "The unique suffix for resource names (CI provided)"
}

variable "service_account" {
  type        = string
  description = "The service account email to associate with GKE nodes"
}
