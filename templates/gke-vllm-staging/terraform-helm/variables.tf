variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP Region"
  default     = "us-central1"
}

variable "cluster_name" {
  type        = string
  description = "Base name for resources"
  default     = "gke-vllm-staging"
}

variable "service_account" {
  type        = string
  description = "Service account for nodes"
}
