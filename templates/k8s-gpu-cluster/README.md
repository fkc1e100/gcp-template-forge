# GKE GPU Cluster Template

This template deploys a GKE cluster with an N1-standard-4 node pool equipped with an NVIDIA T4 GPU.

## Architecture

This template provisions a GKE Standard cluster with a specialized GPU node pool.

- **VPC Network** — Uses the `default` VPC network.
- **GKE Cluster** — A GKE Standard cluster with Vertical Pod Autoscaling enabled.
- **GPU Node Pool** — A single-node pool using `n1-standard-4` machines, each equipped with one NVIDIA Tesla T4 GPU.
- **Workload** — A test Pod running `nvidia-smi` to verify GPU availability.

## Deployment
1. `cd terraform-helm`
2. `terraform init`
3. `terraform apply -var="project_id=YOUR_PROJECT_ID" -var="cluster_name=gpu-cluster"`

## Verification
Run the validation script to ensure the GPU is visible to the workload:
`./validate.sh`

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Validation Record

| | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | pending | pending |
| **Date** | n/a | n/a |
| **Duration** | n/a | n/a |
| **Region** | us-central1 | us-central1 (KCC cluster) |
| **Zones** | - | forge-management namespace |
| **Cluster** | -- | krmapihost-kcc-instance |
| **Agent tokens** | - | (shared session) |
| **Estimated cost** | - | -- |
| **Commit** | n/a | n/a |
