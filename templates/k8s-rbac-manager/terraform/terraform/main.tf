terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# This template is a placeholder for the infrastructure required to run an RBAC manager.
# In a real scenario, this would include IAM roles, Service Accounts, etc.
# For this template, we assume the cluster already exists and we are managing K8s-level access.
