resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnet" {
  name       = var.subnet_name
  ip_cidr_range = "10.0.0.0/24"
  region     = var.region
  network    = google_compute_network.vpc.id
}

variable "vpc_name" { type = string }
variable "subnet_name" { type = string }
variable "region" { type = string }

variable "project_id" {
  type    = string
  default = null
}

variable "project" {
  type    = string
  default = null
}
