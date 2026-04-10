variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "gca-gke-2025"
}

variable "region" {
  description = "The region to deploy the cluster"
  type        = string
  default     = "us-central1"
}

variable "issue_number" {
  description = "The issue number to derive CIDRs"
  type        = number
  default     = 6
}

variable "cluster_name" {
  description = "The name of the cluster"
  type        = string
  default     = "cluster-issue-6"
}

variable "service_account" {
  description = "The service account to use for the node pool"
  type        = string
  default     = "forge-builder@gca-gke-2025.iam.gserviceaccount.com"
}
