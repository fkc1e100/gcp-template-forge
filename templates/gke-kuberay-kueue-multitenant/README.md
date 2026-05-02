# Multi-Tenant Ray on GKE with Equitable Queuing

This template demonstrates how to set up a multi-tenant Ray environment on GKE using [KubeRay](https://ray-project.github.io/kuberay/) and [Kueue](https://kueue.sigs.k8s.io/). It addresses the "Noisy Neighbor" problem by enforcing quotas and allowing equitable borrowing of GPU resources between teams.

## Architecture

*   **GKE Standard Cluster:** A cluster with autoscaling GPU node pools.
*   **KubeRay Operator:** Manages the lifecycle of Ray clusters on Kubernetes.
*   **Kueue:** A cloud-native job scheduler that manages resource quotas and queuing.
*   **Multi-Tenancy:**
    *   `team-a`: Restricted to its nominal quota of 2 GPUs.
    *   `team-b`: Has a nominal quota of 2 GPUs but can borrow up to 2 additional GPUs if they are available.

## Prerequisites

*   A GCP project with GKE and Compute Engine APIs enabled.
*   GPU quota for `nvidia-l4` in your selected region/zone.

## Deployment

### Terraform + Helm Path

1.  Navigate to the terraform directory:
    ```bash
    cd templates/gke-kuberay-kueue-multitenant/terraform-helm
    ```

2.  Initialize and apply Terraform:
    ```bash
    terraform init
    terraform apply -var="project_id=YOUR_PROJECT_ID" -var="service_account=YOUR_SERVICE_ACCOUNT"
    ```

3.  Configure kubectl:
    ```bash
    gcloud container clusters get-credentials ray-kueue-cluster --region us-central1
    ```

4.  Install the workload via Helm:
    ```bash
    helm dependency update workload/
    helm upgrade --install ray-kueue ./workload
    ```

### Config Connector Path

1.  Navigate to the config-connector directory:
    ```bash
    cd templates/gke-kuberay-kueue-multitenant/config-connector
    ```

2.  Apply the infrastructure manifests to your KCC-enabled cluster:
    ```bash
    kubectl apply -f .
    ```

3.  Wait for the GKE cluster and node pools to be ready:
    ```bash
    kubectl wait --for=condition=Ready containercluster ray-kueue-cluster --timeout=30m
    ```

4.  Configure kubectl for the new cluster:
    ```bash
    gcloud container clusters get-credentials ray-kueue-cluster --region us-central1
    ```

5.  Deploy the operators (KubeRay and Kueue):
    ```bash
    cd ../config-connector-workload
    kubectl create namespace kuberay-operator
    kubectl create namespace kueue-system
    kubectl apply --server-side -f kuberay-operator.yaml
    kubectl apply --server-side -f kueue-operator.yaml
    ```

6.  Deploy the multi-tenant workload configurations:
    ```bash
    # Wait for the operators to be running first
    kubectl apply -f workload.yaml
    ```

## Verification

1.  Check the status of the Ray clusters:
    ```bash
    kubectl get raycluster -A
    ```

2.  Verify the Kueue quotas:
    ```bash
    kubectl get clusterqueue
    ```

3.  Observe pods being scheduled across namespaces:
    ```bash
    kubectl get pods -n team-a
    kubectl get pods -n team-b
    ```

## Cleanup

1.  Uninstall Helm release:
    ```bash
    helm uninstall ray-kueue
    ```

2.  Destroy infrastructure:
    ```bash
    terraform destroy
    ```
