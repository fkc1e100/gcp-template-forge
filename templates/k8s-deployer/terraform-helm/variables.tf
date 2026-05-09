variable "project_id" {
  type        = string
  description = "The GCP project ID"
}

variable "region" {
  type        = string
  description = "The GCP region"
  default     = "us-central1"
}

variable "cluster_name" {
  type        = string
  description = "The name of the GKE cluster"
  default     = "k8s-deployer-tf"
}

variable "vpc_name" {
  type        = string
  description = "The name of the VPC network"
  default     = "k8s-deployer-tf-vpc"
}

variable "subnet_name" {
  type        = string
  description = "The name of the subnetwork"
  default     = "k8s-deployer-tf-subnet"
}
