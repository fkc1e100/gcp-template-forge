# Multi-Tenant Ray on GKE with Equitable Queuing

A GKE template demonstrating how to solve the "Noisy Neighbor" problem for shared GPU clusters using the KubeRay Operator and the Kueue Operator. 

## Architecture

- **VPC + Subnet** — VPC with secondary CIDR ranges for pods and services.
- **GKE Standard** — A cluster featuring an autoscaled GPU node pool (using L4 GPUs via `g2-standard-4` spot instances) and a standard system node pool.
- **KubeRay Operator** — Manages the lifecycle of Ray clusters on Kubernetes.
- **Kueue Operator** — Cloud-native job queueing and equitable resource sharing.
- **Workloads** — Two namespaces (`team-a` and `team-b`), each with a Kueue `LocalQueue` linked to a `ClusterQueue` sharing a single GPU `Cohort`. Kueue ensures that if Team A requests excess GPUs, their pods remain in a pending state until Team B finishes their work.

## Prerequisites

- **Google Cloud Project**: You must have a GCP project with billing enabled.
- **APIs Enabled**: Ensure `compute.googleapis.com` and `container.googleapis.com` are enabled.
- **IAM Permissions**: You need permissions to create VPCs, Subnets, GKE clusters, and Service Accounts.
- **Tools**:
  - `gcloud` CLI installed and authenticated.
  - `kubectl` installed.
  - For Terraform: `terraform` CLI installed.
  - For Config Connector: A management cluster with Config Connector installed and configured to manage resources in your GCP project.

## Deployment Paths

### Terraform + Helm (`terraform-helm/`)

```bash
cd terraform-helm
terraform init
terraform apply -var="project_id=my-project-id" -var="service_account=my-service-account@my-project-id.iam.gserviceaccount.com"
# Authenticate to the cluster
gcloud container clusters get-credentials gke-kuberay-kueue --region us-central1

# Deploy the Helm chart
helm upgrade --install release workload/ --wait
```

### Config Connector (`config-connector/`)

1.  Navigate to the directory:
    ```bash
    cd templates/gke-kuberay-kueue-multitenant/config-connector
    ```
2.  Apply the infrastructure manifests:
    ```bash
    kubectl apply -f .
    ```
3.  Wait for the cluster to be ready:
    ```bash
    kubectl wait --for=condition=Ready containercluster ray-kueue-cluster -n forge-management --timeout=30m
    ```
4.  Configure `kubectl` and deploy the operators and workloads:
    ```bash
    gcloud container clusters get-credentials ray-kueue-cluster --region us-central1
    cd ../config-connector-workload
    kubectl create namespace kuberay-operator
    kubectl create namespace kueue-system
    kubectl apply --server-side -f kuberay-operator.yaml
    kubectl apply --server-side -f kueue-operator.yaml
    
    # Wait for the operators to start, then apply the workload
    kubectl apply -f workload.yaml
    ```

## Verification

After deploying, verify the Kueue setup:
```bash
kubectl get clusterqueues
kubectl get localqueues -A
kubectl get rayclusters -A
```
