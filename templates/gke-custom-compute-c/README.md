# GKE Custom Compute Template

This template provisions a GKE Standard cluster with a custom compute node pool using custom machine types (e.g. `e2-custom-4-8192`), and deploys a robust sample workload.

## Architecture

- **VPC & Subnets**: A standalone VPC with subnetwork containing secondary ranges for Pod and Service IPs.
- **GKE Cluster**: A zonal Standard container cluster with deletion protection deactivated.
- **Custom Compute Node Pool**: A custom node pool using `e2-custom-4-8192` machine types.
- **Helm Workload**: Deploys an HTTP web server with LoadBalancer service, readiness, and liveness checks.

## Inputs / Requirements

The following variables are expected to be injected dynamically by CI:

- `project_id`: GCP Project ID.
- `region`: GCP Region.
- `zone`: GCP Zone.
- `cluster_name`: GKE Cluster name.
- `network_name`: VPC Network name.
- `subnet_name`: Subnetwork name.
- `uid_suffix`: Last 6 digits of CI run ID.
- `service_account`: Service account used by GKE node pool.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| project_id | The GCP Project ID | n/a |
| region | The GCP Region | us-central1 |
| zone | The GCP Zone | us-central1-a |
| cluster_name | The name of the GKE cluster | n/a |
| network_name | The VPC network name | n/a |
| subnet_name | The subnet name | n/a |
| uid_suffix | The last 6 digits of the CI run ID | n/a |
| service_account | The CI WIF service account | n/a |

