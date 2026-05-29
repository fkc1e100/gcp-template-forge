# GKE Test KCC Skip

This template creates a Google Kubernetes Engine (GKE) cluster using Terraform and deploys a sample workload to it using Helm.
It deliberately isolates the **Terraform + Helm** path, skipping Config Connector entirely.

## Files
- `terraform-helm/`: Terraform code for deploying the VPC, Subnet, and GKE cluster.
- `terraform-helm/workload/`: Helm chart containing sample deployments and services to be applied to the cluster.

## Deployment
Deployments will set standard CI variables (`TF_VAR_project_id`, `TF_VAR_cluster_name`, etc.) which map to `variables.tf`.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| project_id | GCP project ID | n/a |
| region | GCP region | us-central1 |
| zone | GCP zone | us-central1-a |
| cluster_name | Cluster name | n/a |
| network_name | VPC network name | n/a |
| subnet_name | VPC subnet name | n/a |
| uid_suffix | UID suffix for uniqueness | n/a |
| service_account | CI WIF service account | n/a |

