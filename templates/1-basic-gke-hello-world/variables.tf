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

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,38}[a-z0-9]$", var.cluster_name))
    error_message = "The cluster_name must start with a lowercase letter, contain only lowercase letters, numbers, and hyphens, and be between 1 and 40 characters long."
  }
}
