terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  project = "gca-gke-2025"
  region  = "us-central1"
}

provider "random" {}

resource "google_storage_bucket" "test_workload_bucket" {
  name          = "test-workload-terraform-bucket-${random_id.bucket_suffix.hex}"
  location      = "US"
  force_destroy = true
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}
