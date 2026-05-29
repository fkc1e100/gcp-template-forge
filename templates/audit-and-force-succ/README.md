# Audit and Force Success GKE Template

This template provisions a GKE Standard cluster with secure network infrastructure and deploys an audited workload using Helm.

## Architecture

- **VPC & Subnet**: Dedicated custom VPC and subnetwork with no public IP exposure except via GKE.
- **GKE Standard Cluster**: Regional cluster pinned to a single node zone (`node_locations`) using `var.zone`.
- **Nginx Web Service**: A simple, secure container deployed via Helm, verified with a LoadBalancer service.

## Verification

The included `validate.sh` script automates the verification process:
1. Fetches cluster credentials.
2. Installs or upgrades the Helm chart in the `workload/` directory.
3. Waits for pod availability and external LoadBalancer IP.
4. Performs an end-to-end HTTP verification using `curl`.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| project_id | The GCP Project ID | n/a |
| region | The region to deploy resources to | us-central1 |
| zone | The zone to deploy the node pool to | us-central1-a |
| cluster_name | The GKE cluster name (provided by CI) | n/a |
| network_name | The VPC network name (provided by CI) | n/a |
| subnet_name | The VPC subnetwork name (provided by CI) | n/a |
| uid_suffix | Unique identifier suffix (provided by CI) | n/a |
| service_account | The service account for Workload Identity / CI (provided by CI) | n/a |

