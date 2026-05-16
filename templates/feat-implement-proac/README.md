# Proactive Rebasing Watcher (`feat-implement-proac`)

This template provisions a GKE cluster running a simulated "Watcher" service for proactive rebasing loops.

## Deployment Paths

### Terraform + Helm (`terraform-helm/`)
Deploys standard GKE cluster with VPC using Terraform. The Watcher service is deployed via a Helm chart.
*(Note: Terraform implementation is provided in a parallel PR).*

### Config Connector (`config-connector/`)
Deploys the GCP infrastructure natively via Kubernetes manifests using GCP Config Connector.

1. Apply the networking stack: `kubectl apply -f config-connector/network.yaml`
2. Apply the GKE cluster: `kubectl apply -f config-connector/cluster.yaml`
3. Apply the node pool: `kubectl apply -f config-connector/nodepool.yaml`
4. Deploy workload to the PROVISIONED cluster: `kubectl apply -f config-connector-workload/workload.yaml`

## Validation

Run `./validate.sh` against your provisioned GKE cluster. The validation script:
1. Verifies node availability.
2. Waits for the Watcher pods to become `Ready`.
3. Polls the Service for an external LoadBalancer IP.
4. Performs an HTTP GET request to verify the Watcher is actively serving traffic.
