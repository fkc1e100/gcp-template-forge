variable "project_id" {
  type        = string
  description = "The GCP project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  type        = string
}

variable "cluster_zone" {
  type        = string
}
