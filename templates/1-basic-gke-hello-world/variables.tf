variable "project_id" {
  description = "The GCP project ID to deploy the cluster into."
  type        = string
}

variable "region" {
  description = "The GCP region to deploy the cluster into."
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The name of the GKE cluster."
  type        = string
  default     = "hello-world-cluster"
}
