# GKE GPU Cluster Template

This template deplies a GKE cluster with an N1-standard-4 node pool equipped with an NVIDIA T4 GPU.

## Deployment
1. `cd terraform`
2. `terraform init`
3. `terraform apply -var="project_id=YOUR_PROJECT_ID" -var="cluster_name=gpu-cluster"`

## Verification
Run the validation script to ensure the GPU is visible to the workload:
`./validate.sh`
