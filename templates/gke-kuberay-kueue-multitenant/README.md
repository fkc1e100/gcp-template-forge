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
    - `ResourceFlavor`: `base-flavor` and `default-flavor`.
    - `ClusterQueues`: `team-a-cq` and `team-b-cq` sharing a common `gpu-cohort`.
    - `LocalQueues`: `team-a-lq` and `team-b-lq` in their respective namespaces.
  - **Quotas**: Each team has a nominal quota of 2 GPUs but can borrow up to the total capacity (4 GPUs) if the other team is not using it. `base-flavor` has 0 GPU quota to steer head pods to non-GPU nodes.
  - **ResourceQuota & LimitRange**: Applied to `team-a` and `team-b` to manage non-batch workload resources.

## Kueue Resource Management

### Cohorts & Borrowing
Both teams belong to the `gpu-cohort`. This allows a team to "borrow" unused GPU quota from the other team. For example, if Team B is idle, Team A can use all 4 GPUs. However, as soon as Team B requests resources, Kueue will manage the allocation according to the nominal quotas.

### Preemption Policies
Kueue's preemption is configured to ensure that borrowing workloads are preempted when the rightful owner of the quota requests it. In this template:
- `RayCluster` resources are admitted via `LocalQueues`.
- When a higher-priority or "rightful owner" workload enters the queue, Kueue will trigger preemption of lower-priority borrowing workloads to reclaim the `nominalQuota`.

### Explicit Timeouts
This template uses an explicit **30-minute timeout** for GKE node pool operations in Terraform. This is necessary because GPU node provisioning and autoscaling can occasionally take longer than default timeouts due to resource availability or quota checks.

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

> **Note**: GKE provisioning typically takes **up to 30 minutes**.

The Helm chart in `workload/` installs everything needed: operators, namespaces, Kueue resources, and sample RayClusters.

### Config Connector (`config-connector/`)

This path uses Google Cloud Config Connector (KCC) to manage GCP resources as Kubernetes objects.

```bash
# Update project-id in config-connector/cluster.yaml if necessary
# (Default is gca-gke-2025)

# Apply infrastructure resources to the management cluster
kubectl apply -n forge-management -f config-connector/

# Wait for infrastructure to be ready (up to 30 minutes)
# You can check the status using:
kubectl get -n forge-management -f config-connector/

# Once all resources show READY: True, apply the workload to the workload cluster:
# (Ensure you are connected to the newly created workload cluster)
kubectl apply --server-side -f config-connector-workload/
```

## Security & Isolation

### GPU Driver Installer
The `nvidia-driver-installer` DaemonSet runs in the `kube-system` namespace with:
- **Privileged**: Required for loading kernel modules.
- **HostNetwork & HostPID**: Required for interacting with the host OS.

### Ray Dashboard
The Ray dashboard is exposed on `0.0.0.0:8265` within the head pod. This template includes a `NetworkPolicy` (`ray-dashboard-restriction`) in both `team-a` and `team-b` namespaces that restricts ingress to the head pod from only within the same namespace. For production, you may want to further restrict this to specific monitoring namespaces or use an Ingress with authentication.

## Verification

The `validate.sh` script performs comprehensive checks on operator readiness, Kueue configurations, and RayCluster status. It strictly performs validation and readiness checks, as all deployment actions are delegated to the CI pipeline and Helm.

```bash
./validate.sh
```

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
| **Date** | 2026-04-21 | 2026-04-21 |
| **Duration** | n/a | n/a |
| **Region** | us-central1 | us-central1 (KCC cluster) |
| **Zones** | us-central1-a,b,c | us-central1-a,b,c |
| **Cluster** | gke-kuberay-kueue-multitenant | gke-kuberay-kueue-multitenant |
| **Agent tokens** | not recorded | (shared session) |
| **Estimated cost** | - | -- |
| **Commit** | 38c85cc | 38c85cc |
