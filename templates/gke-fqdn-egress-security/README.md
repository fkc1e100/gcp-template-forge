# GKE Zero-Trust AI Egress with FQDN Network Policies

This template demonstrates how to implement a "Default Deny" egress policy in GKE and selectively allow traffic to specific external AI services using Fully Qualified Domain Name (FQDN) Network Policies.

## Overview
Securing egress traffic is a critical component of a Zero-Trust architecture. In GKE, FQDN Network Policies allow you to define egress rules based on domain names rather than static IP addresses, which is essential for interacting with third-party AI APIs (like Anthropic or HuggingFace) where IP ranges can change frequently.

## Features
- **Dataplane V2:** High-performance eBPF-based networking (required for FQDN policies).
- **FQDN Network Policies:** Granular egress control using domain patterns (e.g., `*.anthropic.com`). Promoted to GA (`v1`) in GKE 1.35.
- **Zero-Trust Security:** A default-deny egress policy ensures that only explicitly allowed traffic can leave the cluster.
- **GKE Enterprise Integration:** Automatic fleet registration to enable advanced security features.

## Architecture
- **GKE Cluster:** A private cluster with Dataplane V2 and FQDN Network Policy enabled.
- **NetworkPolicy (`default-deny-egress`):** Denies all egress except for DNS (UDP/TCP 53) to allow FQDN resolution.
- **FQDNNetworkPolicy (`allow-ai-egress`):** Allows HTTPS (TCP 443) traffic to:
    - `anthropic.com`, `api.anthropic.com`, `*.anthropic.com`
    - `huggingface.co`, `*.huggingface.co`
    - `hf.co`, `*.hf.co`
- **Validation Pod:** A `curl`-based pod used to verify connectivity.

## Prerequisites
- A Google Cloud Project with billing enabled.
- `gcloud`, `kubectl`, `terraform`, and `helm` installed locally.
- GKE Enterprise enabled in your project (required for FQDN Network Policies).
- For Config Connector: KCC installed and configured in a management cluster.

## Deployment

### Option 1: Terraform & Helm (Recommended)
This path uses Terraform to provision the infrastructure and Helm to deploy the security policies and validation workload.

1.  **Initialize and Apply Infrastructure:**
    ```bash
    cd terraform-helm
    terraform init
    terraform apply
    ```
2.  **Verify Workload Deployment:**
    Terraform generates a `values.yaml` for Helm. The CI pipeline or a manual `helm install` will deploy the manifests in the `workload/` directory.

### Option 2: Config Connector
This path uses Kubernetes manifests to manage both the GCP infrastructure and the GKE workloads.

1.  **Deploy Infrastructure:**
    Apply the manifests to your KCC management cluster:
    ```bash
    kubectl apply -f config-connector/
    ```
2.  **Wait for Readiness:**
    Use the following command to check the status of the cluster:
    ```bash
    kubectl wait --for=condition=Ready containercluster/gke-fqdn-egress-security-cluster -n forge-management --timeout=30m
    ```
3.  **Deploy Workload:**
    Once the cluster is ready, get credentials and apply the workload manifests:
    ```bash
    gcloud container clusters get-credentials gke-fqdn-egress-security-cluster --region us-central1
    kubectl apply -f config-connector-workload/
    ```

## Verification

The included `validate.sh` script automates the entire verification process, including waiting for CRDs and testing connectivity to allowed/blocked domains.

```bash
./validate.sh
```

### Manual Verification
1.  **Test Allowed Egress (Anthropic):**
    ```bash
    kubectl exec egress-verifier -n <namespace> -- curl -sL -4 --connect-timeout 10 https://api.anthropic.com
    ```
2.  **Test Allowed Egress (HuggingFace):**
    ```bash
    kubectl exec egress-verifier -n <namespace> -- curl -sL -4 --connect-timeout 10 https://huggingface.co
    ```
3.  **Test Blocked Egress (Google):**
    ```bash
    kubectl exec egress-verifier -n <namespace> -- curl -sL -4 --connect-timeout 10 https://google.com
    # This should time out or return an error.
    ```

## Cleanup

### Terraform Cleanup
```bash
cd terraform-helm
terraform destroy
```

### Config Connector Cleanup
```bash
kubectl delete -f config-connector/
```
