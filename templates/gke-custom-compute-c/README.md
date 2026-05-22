# GKE Custom Compute Classes — Terraform + Helm

This template provisions a GKE cluster with a custom, high-performance node pool featuring a custom machine type (`e2-custom-4-8192`), and deploys a Helm-managed workload pinned to run specifically on that pool using Kubernetes NodeSelectors.

## Directory Structure
- `template.yaml`: Template configuration metadata.
- `terraform-helm/`: Terraform code to construct the infrastructure.
  - `main.tf`: VPC network, Subnetwork, GKE Zonal Cluster, and Custom Node Pool.
  - `variables.tf`, `outputs.tf`, `versions.tf`: Input, output, and dependency metadata.
  - `workload/`: Helm chart for deploying the demo web server on GKE custom nodes.
- `validate.sh`: Active validation suite verifying GKE API availability, Helm release deployment, dynamic LoadBalancer allocation, and curl responsiveness.
