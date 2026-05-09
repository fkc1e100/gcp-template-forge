variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
}

variable "zone" {
  type        # Used for node pool location
  description = "GCP Zone"
}

variable "cluster_name" {
  type    = string
  default = "gke-spot-cluster"
}
