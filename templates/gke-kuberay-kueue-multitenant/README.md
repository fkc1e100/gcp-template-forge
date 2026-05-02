# Multi-Tenant Ray on GKE with Equitable Queuing (Kueue)

This template demonstrates how to set up a multi-tenant Ray environment on GKE using [KubeRay](https://ray-project.github.io/kuberay-helm/) and [Kueue](https://kueue.sigs.k8s.io/). It focuses on equitable GPU sharing between teams using Kueue's `ClusterQueues`, `Cohorts`, and `LocalQueues`.

## Architecture

- **GKE Cluster**: A standard GKE cluster with a GPU-enabled node pool (NVIDIA L4 GPUs).
- **KubeRay Operator**: Manages the lifecycle of Ray clusters on Kubernetes.
- **Kueue Operator**: Manages job queuing and resource quotas, ensuring that teams share GPUs fairly.
- **Multi-Tenancy**: Two namespaces (`team-a` and `team-b`) each with their own `LocalQueue` and `RayCluster`.
- **Equitable Sharing**: Both teams share a common `cohort`. If one team is not using their quota, the other can borrow it, but Kueue ensures that each team has a guaranteed nominal quota when needed.

## Prerequisites

- A Google Cloud Project with billing enabled.
- GPU quota for NVIDIA L4 GPUs in the chosen region (default: `us-central1`).
- `gcloud`, `terraform`, `kubectl`, and `helm` installed locally.

## Deployment

### Terraform + Helm Path

1.  **Initialize and Apply Terraform**:
    ```bash
    cd terraform-helm
    terraform init
    terraform apply -var="project_id=YOUR_PROJECT_ID" -var="service_account=YOUR_SERVICE_ACCOUNT"
    ```

2.  **Deploy Workloads**:
    The CI/CD pipeline automatically deploys the Helm chart located in `terraform-helm/workload`. To do it manually:
    ```bash
    gcloud container clusters get-credentials kuberay-kueue-tf --region us-central1 --project YOUR_PROJECT_ID
    helm upgrade --install release ./workload --wait
    ```

## Verification

Run the provided validation script:
```bash
./validate.sh
```

Or manually verify:
1.  Check that both RayClusters are created:
    ```bash
    kubectl get raycluster -A
    ```
2.  Check Kueue admission status:
    ```bash
    kubectl get workload -A
    ```
3.  Observe that if one team requests more than the total cohort capacity, the extra workloads remain in `Pending` (admitted by Kueue but waiting for resources) or `QuotaReserved` depending on the state.

## Cleanup

```bash
terraform destroy -var="project_id=YOUR_PROJECT_ID" -var="service_account=YOUR_SERVICE_ACCOUNT"
```
