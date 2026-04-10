variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region to deploy the GKE cluster"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "basic-gke-cluster"
}
