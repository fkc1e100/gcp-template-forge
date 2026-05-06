# Multi-Tenant Ray on GKE with Equitable Queuing

> solve the "Noisy Neighbor" problem for shared GPU clusters using KubeRay and Kueue

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Architecture

This template demonstrates how to solve the "Noisy Neighbor" problem for shared GPU clusters using the KubeRay Operator and the Kueue Operator.

This template provisions:

- **VPC + Subnet** — VPC with secondary CIDR ranges for pods and services.
- **GKE Standard** — A cluster featuring an autoscaled GPU node pool (using L4 GPUs via `g2-standard-4` spot instances) and a standard system node pool.
- **KubeRay Operator** — Manages the lifecycle of Ray clusters on Kubernetes.
- **Kueue Operator** — Cloud-native job queueing and equitable resource sharing.
- **Workloads** — Two namespaces (`team-a` and `team-b`), each with a Kueue `LocalQueue` linked to a `ClusterQueue` sharing a single GPU `Cohort`. Kueue ensures that if Team A requests excess GPUs, their pods remain in a pending state until Team B finishes their work.

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `gke-kuberay-kueue-<uid>-tf` | `gke-kuberay-kueue-<uid>-kcc` |
| VPC Network | `gke-kuberay-kueue-<uid>-tf-vpc` | `gke-kuberay-kueue-<uid>-kcc-vpc` |
| Subnet | `gke-kuberay-kueue-<uid>-tf-subnet` | `gke-kuberay-kueue-<uid>-kcc-subnet` |

---

## Deployment Paths

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/kuberay-kueue/terraform-helm
terraform init
terraform apply -var="project_id=YOUR_PROJECT_ID" -var="service_account=YOUR_NODE_SA"
```

### Path 2: Config Connector (KCC)

**Prerequisites:** A running GKE cluster with Config Connector installed.

1.  Navigate to the directory:
    ```bash
    cd templates/kuberay-kueue/config-connector
    ```
2.  Apply the infrastructure manifests:
    ```bash
    kubectl apply -n forge-management -f .
    ```
3.  Wait for the cluster to be ready:
    ```bash
    kubectl wait --for=condition=Ready containercluster kuberay-kueue-cluster-kcc -n forge-management --timeout=30m
    ```
4.  Configure `kubectl` and deploy the operators and workloads:
    ```bash
    gcloud container clusters get-credentials kuberay-kueue-cluster-kcc --region us-central1
    cd ../config-connector-workload
    kubectl create namespace kuberay-operator
    kubectl create namespace kueue-system
    kubectl apply --server-side -f kuberay-operator.yaml
    kubectl apply --server-side -f kueue-operator.yaml
    
    # Wait for the operators to start, then apply the workload
    kubectl apply -f workload.yaml
    ```

---

## Verification

After deploying, verify the Kueue setup:
```bash
kubectl get clusterqueues
kubectl get localqueues -A
kubectl get rayclusters -A
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `gke-kuberay-kueue` |
| `network_name` | VPC network name | `gke-kuberay-kueue-vpc` |
| `subnet_name` | Subnet name | `gke-kuberay-kueue-subnet` |
| `service_account` | Node pool service account | required |
| `uid_suffix` | Unique suffix for resource names | `""` |
