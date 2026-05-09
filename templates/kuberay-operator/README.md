# KubeRay Operator on GKE

This template deploys the KubeRay Operator onto a Google Kubernetes Engine cluster.

## Architecture

This template deploys the KubeRay Operator onto a Google Kubernetes Engine (GKE) cluster.

The following resources are provisioned:
- **GKE Cluster**: A standard GKE cluster with a single node pool (e2-medium nodes).
- **KubeRay Operator**: Deployed into the `kubeflow` namespace to manage Ray clusters on GKE.

## Prerequisites
- GCP Project with GKE API enabled.
- Terraform installed.
- kubectl configured.

## Deployment Steps
1. Navigate to `terraform/`.
2. Run `terraform init` and `terraform apply`.
3. Apply Kubernetes manifests: `kubectl apply -f ../kubernetes/`.

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->
## Validation Record
