# GKE Custom Compute Node Pool (Terraform + Helm)

This template provisions a zonal GKE cluster with a dedicated node pool optimized with custom compute shapes (`e2-custom-4-16384` with 4 vCPUs and 16 GB of RAM) and labels. It deploys a standard workload with Helm and verifies scheduling on the custom node pool.

## Components
- **VPC & Subnet**: Custom VPC designed specifically for private Google access and secondary IP ranges for GKE. No labels configured on subnet resource as per rules.
- **GKE Cluster**: Zonal GKE standard cluster with workload identity enabled.
- **Custom Compute Node Pool**: Configured with custom instance configurations (`e2-custom-4-16384`) and explicit node locations.
- **Workload**: Helm deployment utilizing `nodeSelector` to ensure pods are scheduled onto the custom compute nodes.

## Variables
- `project_id`: GCP Project ID
- `region`: GCP Region (default: `us-central1`)
- `zone`: GCP Zone (default: `us-central1-a`)
- `cluster_name`: GKE Cluster Name (auto-provided by CI)
- `network_name`: VPC Network Name (auto-provided by CI)
- `subnet_name`: Subnetwork Name (auto-provided by CI)
- `uid_suffix`: A unique suffix identifier (auto-provided by CI)
- `service_account`: IAM Service Account for GKE nodes (auto-provided by CI)

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| project_id | The GCP project ID to deploy into | n/a |
| region | The GCP region | us-central1 |
| zone | The GCP zone | us-central1-a |
| cluster_name | The GKE cluster name | n/a |
| network_name | The VPC network name | n/a |
| subnet_name | The subnetwork name | n/a |
| uid_suffix | Suffix for resource uniqueness | n/a |
| service_account | Service account for the GKE nodes | n/a |

