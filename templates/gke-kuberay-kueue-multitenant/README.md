# Multi-Tenant Ray on GKE with Equitable Queuing

This template demonstrates how to deploy a multi-tenant Ray on GKE environment using KubeRay and Kueue. It ensures equitable resource sharing across teams (team-a and team-b) with queueing.

## Architecture
- **GKE Cluster**: A GKE cluster with a CPU pool and a GPU pool (L4).
- **KubeRay Operator**: Manages the lifecycle of RayClusters.
- **Kueue**: Kubernetes-native job queueing and resource management.
- **Queues**: A single `ClusterQueue` representing the cluster's resources, and two `LocalQueue`s (one for `team-a`, one for `team-b`).

## Prerequisites
- A Google Cloud Project.
- Terraform or Config Connector installed.
- `kubectl`, `helm` (for TF), `gcloud`.

## Deployment

### Option 1: Config Connector (KCC)
1. Deploy the infrastructure:
   ```bash
   kubectl apply -f config-connector/
   ```
2. Wait for the cluster to be ready.
3. Deploy the workload manifests (Kueue, KubeRay, Queues, RayClusters):
   ```bash
   kubectl apply -f config-connector-workload/
   ```

### Option 2: Terraform + Helm
1. Initialize and apply Terraform:
   ```bash
   cd terraform-helm/
   terraform init
   terraform apply
   ```

## Verification
To verify the deployment:
1. Ensure the operators are running:
   ```bash
   kubectl get pods -n kueue-system
   kubectl get pods -n kuberay-system
   ```
2. Check the ClusterQueue status:
   ```bash
   kubectl get clusterqueue cluster-queue
   ```
   You should see 1 admitted workload and 1 pending workload, demonstrating Kueue's equitable resource sharing based on available GPU quota.

## Cleanup
- **KCC**: `kubectl delete -f config-connector/`
- **Terraform**: `terraform destroy`
