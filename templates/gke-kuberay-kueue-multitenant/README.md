# GKE KubeRay and Kueue Multitenant Template

This template provisions a Google Kubernetes Engine (GKE) standard cluster configured for multitenant GPU sharing. It uses [KubeRay](https://ray-project.github.io/kuberay/) to manage Ray clusters and [Kueue](https://kueue.sigs.k8s.io/) to enforce equitable sharing between teams via `ClusterQueue`s and `LocalQueue`s.

## Features
- **GKE Standard Cluster**: Provisioned with a standard node pool and an autoscaling GPU node pool.
- **L4 GPU Acceleration**: Uses `g2-standard-4` machines for worker workloads.
- **Workload Identity**: Configured to securely link Kubernetes Service Accounts (KSA) to Google Service Accounts (GSA).
- **KubeRay Operator**: Automatically deployed to manage Ray workloads.
- **Kueue Operator**: Deployed to handle resource quotas (`nominalQuota` and `borrowingLimit`).
- **Equitable Sharing**: Configured with two `ClusterQueue`s (team-a and team-b) in the same cohort to allow borrowing up to limits while maintaining fairness.

## Architecture

1.  **VPC & Subnet**: A dedicated VPC and Subnet.
2.  **GKE Cluster**: A Standard cluster running KubeRay and Kueue operators.
3.  **Ray Workloads**: Sample `RayCluster` CRDs are submitted to `team-a` and `team-b` namespaces to demonstrate how jobs are queued and admitted based on quota.

## Deployment Paths

This template supports both **Terraform + Helm** and **Config Connector** deployments.

### Terraform + Helm Path

1.  **Initialize Terraform:**
    ```bash
    cd terraform-helm
    terraform init
    ```
2.  **Apply Infrastructure:**
    ```bash
    terraform apply -var="project_id=YOUR_PROJECT_ID" -var="service_account=YOUR_SA_EMAIL"
    ```
3.  **Deploy Workload (Helm):**
    ```bash
    gcloud container clusters get-credentials ray-kueue-tf-cluster --region us-central1 --project YOUR_PROJECT_ID
    helm upgrade --install release ./workload --namespace default
    ```

### Config Connector Path

Ensure Config Connector is installed on your management cluster and configured to manage resources in your target project.

1.  **Apply Infrastructure:**
    ```bash
    cd config-connector
    kubectl apply -f network.yaml
    kubectl apply -f cluster.yaml
    kubectl apply -f nodepool.yaml
    ```
2.  **Wait for Readiness:** Wait for the cluster and node pools to be ready.
3.  **Deploy Workload:**
    ```bash
    gcloud container clusters get-credentials ray-kueue-kcc-cluster --region us-central1 --project YOUR_PROJECT_ID
    kubectl apply -f ../config-connector-workload/workload.yaml
    ```

## Verification
You can use the provided `validate.sh` script (requires `PROJECT_ID`, `CLUSTER_NAME` and `REGION` environment variables) to verify the deployment.
