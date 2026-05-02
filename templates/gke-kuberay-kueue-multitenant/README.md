# Template: Multi-Tenant Ray on GKE with Equitable Queuing

## Overview
This template demonstrates how to build a multi-tenant GPU cluster using **KubeRay** and **Kueue** on GKE. It solves the "noisy neighbor" problem by enforcing quotas and allowing equitable sharing (borrowing) of GPU resources between different teams.

## Key Features
- **GKE Ray Operator Add-on**: Uses the managed GKE Ray operator for lifecycle management of Ray clusters.
- **Kueue Integration**: Implements `ClusterQueues` and `LocalQueues` to manage resource distribution.
- **Multi-Tenancy**: Configures separate namespaces (`team-a` and `team-b`) with dedicated quotas.
- **Equitable Sharing**: Uses Kueue `cohorts` to allow teams to borrow unused capacity from each other while guaranteeing their own `nominalQuota`.
- **GPU Acceleration**: Uses NVIDIA L4 GPUs on G2-standard-4 spot instances.

## Infrastructure Architecture
- **GKE Standard Cluster**: With Ray Operator and GCS FUSE add-ons enabled.
- **System Node Pool**: For running the Kueue operator and Ray head pods.
- **GPU Node Pool**: Autoscaled pool of `g2-standard-4` nodes with NVIDIA L4 GPUs.

## Template Paths

### Terraform + Helm (`terraform-helm/`)
- Provisions the VPC, Subnet, GKE cluster, and Node Pools.
- Deploys Kueue and the multi-tenant Ray workload via Helm.

## Deployment Instructions

### Prerequisites
- A GCP Project with Billing enabled.
- GPU Quota for `NVIDIA_L4_GPUS` in `us-central1`.
- `terraform`, `helm`, `kubectl`, and `gcloud` installed.

### Terraform + Helm Path

1.  **Provision Infrastructure**:
    ```bash
    cd terraform-helm
    terraform init
    terraform apply -var="project_id=<PROJECT_ID>" -var="service_account=<SERVICE_ACCOUNT_EMAIL>"
    ```

2.  **Verify**:
    ```bash
    cd ..
    ./validate.sh
    ```

## Verification Scenario
The `validate.sh` script performs the following:
1.  Installs the **Kueue** operator.
2.  Deploys the `ray-kueue-multi` Helm chart which creates:
    - Namespaces `team-a` and `team-b`.
    - Kueue `ClusterQueues` with a shared `cohort`.
    - `RayCluster` resources in each namespace.
3.  Verifies that `RayCluster` pods are created and scheduled via Kueue.
4.  (Optional) Demonstrates queuing by submitting a job that exceeds the total quota.

## Cleanup
```bash
cd terraform-helm
terraform destroy -var="project_id=<PROJECT_ID>" -var="service_account=<SERVICE_ACCOUNT_EMAIL>"
```
