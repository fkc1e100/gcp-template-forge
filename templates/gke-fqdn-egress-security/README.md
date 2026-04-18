# GKE Zero-Trust AI Egress with FQDN Network Policies

This template demonstrates how to implement a "Default Deny" egress policy in GKE and selectively allow traffic to specific external AI services (Anthropic, HuggingFace) using Fully Qualified Domain Name (FQDN) Network Policies.

## Architecture

The template provisions a secure GKE environment with the following components:

1.  **GKE Cluster (Standard):**
    *   **Dataplane V2:** High-performance eBPF-based networking required for FQDN policies.
    *   **GKE Enterprise Advanced Networking:** Required to enable the `FQDNNetworkPolicy` resource.
    *   **Private Cluster:** Nodes have only private IP addresses for enhanced security.
    *   **Cloud NAT:** Enables outbound internet access for private nodes.
2.  **Network Policies:**
    *   `default-deny-egress`: A standard Kubernetes `NetworkPolicy` that blocks all outbound traffic from the namespace except for DNS (UDP/TCP port 53) to allow domain resolution.
    *   `allow-ai-egress`: A GKE-specific `FQDNNetworkPolicy` that allow HTTPS (port 443) traffic to specific domains and their subdomains (e.g., `*.anthropic.com`, `*.huggingface.co`).
3.  **Workload:**
    *   `egress-verifier`: A Pod running a `curl` image used to verify the connectivity rules.

## Prerequisites

*   A Google Cloud Project with billing enabled.
*   The `gcloud` CLI installed and authenticated.
*   `kubectl` and `terraform` (>= 1.7) installed.
*   **GKE Enterprise:** The project must have the GKE Enterprise API enabled, as FQDN Network Policies are an Enterprise feature.

## Deployment

### Option 1: Terraform & Helm (Recommended)

This path uses Terraform to provision the infrastructure and a local Helm chart for the workload.

1.  Initialize and apply the infrastructure:
    ```bash
    cd terraform-helm
    terraform init
    terraform apply
    ```
    *Terraform will output the cluster name and location, and automatically generate a `values.yaml` for the Helm chart.*

2.  The CI/CD pipeline or a manual Helm command can then deploy the workload. Manual command:
    ```bash
    gcloud container clusters get-credentials $(terraform output -raw cluster_name) --region $(terraform output -raw cluster_location)
    helm upgrade --install egress-security ./workload -f workload/values.yaml
    ```

### Option 2: Config Connector (KCC)

This path uses Kubernetes-native resource management via Google Cloud Config Connector.

1.  Ensure Config Connector is installed in your management cluster and configured for your project.
2.  Apply the manifests:
    ```bash
    kubectl apply -f config-connector/
    kubectl apply -f config-connector/workload/
    ```
3.  Wait for the cluster to be ready:
    ```bash
    kubectl wait --for=condition=Ready containercluster gke-fqdn-egress-security-cluster -n forge-management --timeout=30m
    ```

## Verification

### Automated Validation

Run the provided validation script to perform automated connectivity tests:
```bash
./validate.sh
```
The script verifies:
*   Dataplane V2 and FQDN Policy enablement.
*   Successful egress to `api.anthropic.com`, `huggingface.co`, and `hf.co`.
*   Blocked egress to `google.com`.

### Manual Verification

1.  Get credentials for the cluster.
2.  Exec into the verifier pod:
    ```bash
    kubectl exec -it egress-verifier -- /bin/sh
    ```
3.  Test allowed egress:
    ```bash
    curl -I https://api.anthropic.com
    curl -I https://huggingface.co
    ```
4.  Test blocked egress (should timeout):
    ```bash
    curl --connect-timeout 5 https://google.com
    ```

## Cleanup

### Terraform
```bash
cd terraform-helm
terraform destroy
```

### Config Connector
```bash
kubectl delete -f config-connector/workload/
kubectl delete -f config-connector/
```
