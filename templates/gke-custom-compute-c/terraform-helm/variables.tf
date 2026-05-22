variable "project_id" {
  type        = string
  description = "The GCP Project ID to host resources"
}

variable "region" {
  type        = string
  description = "The GCP Region to deploy regional components"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "The initial Zone for compute workloads"
  default     = "us-central1-a"
}

variable "cluster_name" {
  type        = string
  description = "Name of the GKE cluster managed by CI"
}

variable "network_name" {
  type        = string
  description = "Name of the GCE VPC network managed by CI"
}

variable "subnet_name" {
  type        = string
  description = "Name of the subnet managed by CI"
}

variable "uid_suffix" {
  type        = string
  description = "Unique short suffix allocated by CI"
}

variable "service_account" {
  type        = string
  description = "The GKE Node service account identifier"
}
