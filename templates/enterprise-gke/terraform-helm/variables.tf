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
  description = "The name of the GKE cluster"
  type        = string
  default     = "enterprise-gke-tf"
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
  default     = "enterprise-gke-tf-net"
}

variable "subnet_name" {
  description = "The name of the subnet"
  type        = string
  default     = "enterprise-gke-tf-subnet"
}

variable "service_account" {
  description = "The service account to use for the GKE nodes if create_service_accounts is false (passed by CI)"
  type        = string
  default     = ""

  validation {
    condition     = var.create_service_accounts || var.service_account != ""
    error_message = "An explicit service account must be provided when create_service_accounts is false to prevent fallback to the Compute Engine default service account."
  }
}

variable "workload_service_account" {
  description = "The service account to use for the Workload Identity if create_service_accounts is false"
  type        = string
  default     = ""
}

variable "create_service_accounts" {
  description = "Whether to create dedicated service accounts. Set to false in environments with restricted IAM permissions (like CI)."
  type        = bool
  default     = false
}

variable "master_authorized_networks" {
  description = "List of master authorized networks. If empty, the cluster endpoint will be open to the internet."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}
