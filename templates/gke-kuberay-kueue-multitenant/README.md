# Multi-Tenant Ray on GKE with Equitable Queuing (Kueue)

This template demonstrates how to set up a multi-tenant Ray environment on GKE using KubeRay and Kueue for equitable resource sharing and queuing.

## Overview
Platform teams often face the "Noisy Neighbor" problem where one team's massive job starves others of GPU resources. This template solves this by:
1.  **GKE Standard Cluster:** A robust foundation with autoscaled GPU node pools.
2.  **Kueue:** A cloud-native job queuing system that manages resource quotas and fair sharing across namespaces.
3.  **KubeRay:** The standard operator for managing Ray clusters on Kubernetes.

## Features
- **Equitable Sharing:** Configure `ClusterQueues` and `LocalQueues` with strict `nominalQuota` to ensure every team gets their fair share of GPUs.
- **Resource Borrowing:** (Optional) Configure cohorts to allow teams to borrow unused capacity from others while guaranteeing their own base quota.
- **Multi-Tenancy:** Separate namespaces (`team-a`, `team-b`) with isolated Ray clusters.
- **GPU Time-Sharing:** Optimized GPU utilization using NVIDIA GPU time-sharing on T4 GPUs.

## Architecture
- **VPC & Subnet:** Custom VPC with secondary ranges for GKE.
- **GKE Cluster:** Standard cluster with Dataplane V2 and Workload Identity.
- **Node Pools:**
    - `system-pool`: Spot e2-standard-4 nodes for operators and head pods.
    - `gpu-pool`: Spot n1-standard-4 nodes with NVIDIA Tesla T4 GPUs (time-shared) for Ray workers.
- **Kueue Resources:**
    - `ResourceFlavor`: `default-flavor`
    - `ClusterQueue`: `cluster-queue` with a total quota of 2 GPUs.
    - `LocalQueue`: `ray-queue` in both `team-a` and `team-b` namespaces.

## Deployment

### Terraform & Helm
1.  **Provision Infrastructure:**
    ```bash
    cd terraform-helm
    terraform init
    terraform apply
    ```
2.  **Deploy Workload:**
    The Terraform apply generates a `values.yaml`. Install the Helm chart:
    ```bash
    gcloud container clusters get-credentials ray-kueue-multi-cluster --region us-central1
    helm install release ./workload
    ```

## Verification
The `validate.sh` script automates the verification:
1.  Checks connectivity to the GKE cluster.
2.  Waits for KubeRay and Kueue operators to be ready.
3.  Verifies that the `ClusterQueue` is active.
4.  Ensures that Ray head and worker pods are admitted and start correctly in both namespaces.

```bash
./validate.sh
```
