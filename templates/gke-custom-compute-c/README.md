# GKE Custom Compute classes Template

This IaC module deploys a Google Kubernetes Engine (GKE) regional cluster with a custom Node Pool designed to use Custom GCE Machine Types (`custom-4-16384` with 4 vCPUs and 16GB RAM) rather than pre-defined system profiles.

This ensures applications requiring specific ratio configurations (CPU-to-memory ratios) can run cost-efficiently within an automated GKE node pool.

## Contents
- `template.yaml`: Template metadata
- `terraform-helm/`: Terraform code to deploy VPC, regional GKE cluster, Custom compute node pool.
- `terraform-helm/workload/`: Helm chart deploying standard web service explicitly scheduled on custom compute node templates.
- `validate.sh`: Validation script ensuring that the custom application gets scheduled properly and behaves correctly.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| project_id | The GCP Project ID to host resources | n/a |
| region | The GCP Region to deploy regional components | us-central1 |
| zone | The initial Zone for compute workloads | us-central1-a |
| cluster_name | Name of the GKE cluster managed by CI | n/a |
| network_name | Name of the GCE VPC network managed by CI | n/a |
| subnet_name | Name of the subnet managed by CI | n/a |
| uid_suffix | Unique short suffix allocated by CI | n/a |
| service_account | The GKE Node service account identifier | n/a |

