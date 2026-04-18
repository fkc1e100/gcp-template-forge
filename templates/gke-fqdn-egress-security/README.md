# GKE Zero-Trust AI Egress with FQDN Network Policies

This template demonstrates how to implement a "Default Deny" egress policy in GKE and selectively allow traffic to specific external AI services using Fully Qualified Domain Name (FQDN) Network Policies.

## Features
- **Dataplane V2:** High-performance eBPF-based networking.
- **FQDN Network Policies:** Allow egress to specific domains without managing static IP lists.
- **Zero-Trust Security:** Default deny all egress to prevent data exfiltration.
- **AI-Focused:** Pre-configured for Anthropic and HuggingFace APIs.

> **Note:** FQDN Network Policies require GKE Dataplane V2 and GKE Enterprise (Advanced Networking) to be enabled on the cluster. This template handles these requirements automatically in the manifests.

## Architecture
1.  **GKE Cluster:** Configured with Dataplane V2 and GKE Enterprise Advanced Networking.
2.  **Network Policies:**
    -   `default-deny-egress`: Denies all egress traffic by default.
    -   `allow-ai-egress`: Selectively allows HTTPS traffic to `api.anthropic.com` and `huggingface.co`.
3.  **Validation Pod:** A simple container used to verify that allowed domains are accessible while others (like `google.com`) are blocked.

## Usage

### Terraform & Helm
```bash
cd terraform-helm
terraform init
terraform apply
```

### Config Connector
1.  **Infrastructure:**
    ```bash
    kubectl apply -f config-connector/
    ```
2.  **Workload:**
    Once the cluster is ready, get credentials and apply the workload:
    ```bash
    gcloud container clusters get-credentials gke-fqdn-egress-security-cluster --region us-central1
    kubectl apply -f config-connector-workload/
    ```

## Verification
The `validate.sh` script automates the verification of the egress policies.
```bash
./validate.sh
```
