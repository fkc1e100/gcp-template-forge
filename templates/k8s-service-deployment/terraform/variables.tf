variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
}

variable "location" {
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  type        = string
}
