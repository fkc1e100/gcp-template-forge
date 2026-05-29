# GKE Workload Consolidation Template

This template deploys a regional GKE cluster with a customized node pool using Terraform, and deploys a robust consolidated Nginx workload using Helm.

## Architecture
- **VPC & Subnet**: Custom VPC designed with GKE-recommended secondary IP ranges for pods and services.
- **Regional GKE Cluster**: High-availability configuration across multiple zones.
- **Helm Workload**: Scalable deployment with internal and external validation endpoints.

## Usage
Inputs and configurations are driven by Terraform variables. The CI/CD pipeline sets these variables dynamically.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| project_id | The GCP Project ID | n/a |
| region | GCP Region | us-central1 |
| zone | GCP Zone | us-central1-a |
| cluster_name | GKE Cluster Name (CI provided) | n/a |
| network_name | VPC Network Name (CI provided) | n/a |
| subnet_name | Subnet Name (CI provided) | n/a |
| uid_suffix | Unique identifier suffix | n/a |
| service_account | Service Account for GCP/WIF | n/a |

