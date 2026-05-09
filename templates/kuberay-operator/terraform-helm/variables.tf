variable "project_id" {
  type        = string
  description = "The GCP project ID"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "cluster_name" {
  type        = string
  description = "The name of the GKE cluster"
}

variable "network_name" {
  type        = string
  description = "The name of the VPC network"
  default     = "default"
}

variable "subnet_name" {
  type        = string
  description = "The name of the subnet"
  default     = "default"
}
