variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "GCP Zone"
}

variable "cluster_name" {
  type    = string
  default = "gke-spot-cluster"
}

variable "service_account" {
  type        = string
  description = "Service account to use for the node pool"
}
