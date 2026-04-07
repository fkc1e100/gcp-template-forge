variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region to deploy the cluster"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The name of the cluster"
  type        = string
  default     = "enterprise-cluster"
}

variable "network" {
  description = "The VPC network to use"
  type        = string
  default     = "default"
}

variable "subnetwork" {
  description = "The subnetwork to use"
  type        = string
  default     = "default"
}

variable "cluster_ipv4_cidr_block" {
  description = "The IP address range of the container pods in this cluster"
  type        = string
  default     = "/14"
}

variable "services_ipv4_cidr_block" {
  description = "The IP address range of the services IPs in this cluster"
  type        = string
  default     = "/20"
}

variable "master_ipv4_cidr_block" {
  description = "The IP address range of the master"
  type        = string
  default     = "172.16.0.0/28"
}

variable "service_account" {
  description = "The service account to use for the node pool"
  type        = string
}
