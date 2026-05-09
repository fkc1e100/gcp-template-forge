# KubeRay Operator on GKE

This template deploys the KubeRay Operator onto a Google Kubernetes Engine cluster.

## Prerequisites
- GCP Project with GKE API enabled.
- Terraform installed.
- kubectl configured.

## Deployment Steps
1. Navigate to `terraform/`.
2. Run `terraform init` and `terraform apply`.
3. Apply Kubernetes manifests: `kubectl apply -f ../kubernetes/`.
