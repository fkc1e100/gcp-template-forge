variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The GKE cluster name"
  type        = string
  default     = "gke-llm-inference-tf"
}

variable "network_name" {
  description = "The VPC network name"
  type        = string
  default     = "gke-llm-inference-tf-vpc"
}

variable "subnet_name" {
  description = "The subnet name"
  type        = string
  default     = "gke-llm-inference-tf-subnet"
}

variable "service_account" {
  description = "The service account to run the GKE nodes"
  type        = string
}

variable "create_workload_sa" {
  description = "Whether to create a dedicated service account for the workload"
  type        = bool
  default     = true
}

variable "workload_service_account_email" {
  description = "Existing GCP service account to use for the workload. If not provided, will use node service account if create_workload_sa is false."
  type        = string
  default     = ""
}
