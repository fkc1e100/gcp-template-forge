# Online Boutique Demo (TF+Helm)

This template demonstrates a mock of the Online Boutique microservices pattern deployed on a GKE cluster. It uses standard deployments and services.

## Architecture

- **VPC / Subnet**: A dedicated VPC network and subnetwork.
- **GKE Cluster**: A standard GKE regional cluster.
- **Node Pool**: A zonal node pool running standard nodes.
- **Workload**: A mock Helm chart containing a multi-tier application (Nginx acting as frontend, Redis acting as cart cache).

## Validation

The `validate.sh` script automatically:
1. Waits for the LoadBalancer IP assignment to the `frontend-online-b` Service.
2. Polls the external IP with HTTP `curl` until a 200 OK response is returned.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| project_id | n/a | n/a |
| region | n/a | us-central1 |
| zone | n/a | us-central1-a |
| cluster_name | n/a | n/a |
| network_name | n/a | n/a |
| subnet_name | n/a | n/a |
| uid_suffix | n/a | n/a |
| service_account | n/a | n/a |

