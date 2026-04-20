# Multi-Tenant Ray on GKE with Equitable Queuing

This template demonstrates how to set up a multi-tenant Ray environment on GKE using [KubeRay](https://ray-project.github.io/kuberay/) and [Kueue](https://kueue.sigs.k8s.io/). It focuses on solving the "Noisy Neighbor" problem by implementing equitable GPU resource sharing between teams.

## Architecture

- **GKE Standard Cluster** — A cluster with two node pools:
  - **System Pool**: `e2-standard-4` spot instances for running operators (KubeRay, Kueue).
  - **GPU Pool**: `g2-standard-4` (NVIDIA L4) spot instances for Ray worker nodes, with autoscaling (0-5 nodes). Restricted to zones `us-central1-a`, `us-central1-b`, and `us-central1-c` to ensure NVIDIA L4 availability.
- **KubeRay Operator** — Manages RayCluster life cycles.
- **Kueue Operator** — Provides job queuing and resource management.
- **Multi-Tenancy Configuration**:
  - **Namespaces**: `team-a` and `team-b`.
  - **Kueue Resources**:
    - `ResourceFlavor`: `default-flavor`.
    - `ClusterQueues`: `team-a-cq` and `team-b-cq` sharing a common `gpu-cohort`.
    - `LocalQueues`: `team-a-lq` and `team-b-lq` in their respective namespaces.
  - **Quotas**: Each team has a nominal quota of 2 GPUs but can borrow up to the total capacity (4 GPUs) if the other team is not using it.

## Deployment Paths

### Terraform + Helm (`terraform-helm/`)

This path uses Terraform to provision the infrastructure and generates a `values.yaml` for the Helm chart.

```bash
cd terraform-helm
terraform init \
  -backend-config="bucket=<TF_STATE_BUCKET>" \
  -backend-config="prefix=templates/gke-kuberay-kueue-multitenant/terraform-helm"
terraform apply -var="project_id=<PROJECT_ID>" -var="service_account=<SERVICE_ACCOUNT_EMAIL>"
```

The Helm chart in `workload/` installs:
1. KubeRay and Kueue operators.
2. Kueue `ResourceFlavor`, `ClusterQueues`, and `LocalQueues`.
3. Team namespaces and sample `RayCluster` resources.

### Config Connector (`config-connector/`)

This path uses Google Cloud Config Connector (KCC) to manage GCP resources as Kubernetes objects.

```bash
# Apply infrastructure resources to the management cluster
kubectl apply -n forge-management -f config-connector/

# Wait for infrastructure to be ready, then apply the workload
# Note: Ensure you are connected to the workload cluster for the following:
# We use --server-side apply to handle large CRDs (e.g. KubeRay) that exceed the annotation limit.
kubectl apply --server-side -f config-connector-workload/
```

## Verification

### 1. Check Operators
Verify that both KubeRay and Kueue operators are running:
```bash
kubectl get pods -A | grep -E "kuberay|kueue"
```

### 2. Verify Kueue Configuration
Check that the ClusterQueues and LocalQueues are active:
```bash
kubectl get clusterqueue
kubectl get localqueue -A
```

### 3. Test Equitable Sharing
The template deploys two RayClusters, each requesting 1 GPU.
1. Scale `raycluster-team-a` to 4 replicas (requesting 4 GPUs).
2. Observe that Kueue allows it to borrow GPUs from the cohort if `team-b` is idle.
3. Deploy a Ray job in `team-b`.
4. Observe that Kueue ensures `team-b` gets its nominal quota, potentially pre-empting or holding `team-a`'s borrowing pods.

## Cleanup

```bash
# Terraform path
cd terraform-helm && terraform destroy

# KCC path
kubectl delete -f config-connector-workload/
kubectl delete -n forge-management -f config-connector/
```

## Validation Record

|  | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | success | success |
| **Date** | 2026-04-20 | 2026-04-20 |
| **Duration** | n/a | n/a |
| **Region** | us-central1 | us-central1 (KCC cluster) |
| **Zones** | us-central1-a,b,c | us-central1-a,b,c |
| **Cluster** | gke-kuberay-kueue-multitenant | gke-kuberay-kueue-multitenant-kcc |
| **Agent tokens** | not recorded | (shared session) |
| **Estimated cost** | - | -- |
| **Commit** | 7c77fd58 | 7c77fd58 |

