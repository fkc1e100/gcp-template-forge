# GKE Zero-Trust FQDN Egress

> Zero-trust egress security with FQDN network policies for controlling AI API traffic from GKE

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Architecture

This template demonstrates how to implement a "Default Deny" egress policy in GKE and selectively allow traffic to specific external AI services using Fully Qualified Domain Name (FQDN) Network Policies. FQDN Network Policies allow you to define egress rules based on domain names rather than static IP addresses, which is essential for interacting with third-party AI APIs (like Anthropic or HuggingFace) where IP ranges can change frequently.

This template provisions:

- **VPC Network** — Dedicated VPC for VPC-native GKE clusters.
- **GKE Cluster** — Private cluster (`gke-fqdn-egress`) with Dataplane V2 and FQDN Network Policy enabled.
- **Workload** — Security policies (Default Deny + AI FQDN Allow) and a validation pod.

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `gke-fqdn-egress-<uid>-tf` | `gke-fqdn-egress-<uid>-kcc` |
| VPC Network | `gke-fqdn-egress-<uid>-tf-vpc` | `gke-fqdn-egress-<uid>-kcc-vpc` |
| Subnet | `gke-fqdn-egress-<uid>-tf-subnet` | `gke-fqdn-egress-<uid>-kcc-subnet` |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| E2 Standard Node Pool (1x e2-standard-4 Spot) | ~$29 |
| GKE Enterprise (included/required) | ~$0 |
| **Total** | **~$104** |

*Estimates based on sustained use in us-central1 with Spot nodes.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured. GKE Enterprise must be enabled in the project.

```bash
cd templates/gke-fqdn-egress-security/terraform-helm

# Initialize
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="prefix=templates/gke-fqdn-egress-security/terraform-helm"

# Apply
terraform apply -var="project_id=YOUR_PROJECT_ID"

# Get credentials
gcloud container clusters get-credentials gke-fqdn-egress-tf --region us-central1

# Deploy workload
helm upgrade --install release ./workload --wait
```

**Cleanup:**
```bash
helm uninstall release
terraform destroy -var="project_id=YOUR_PROJECT_ID"
```

---

### Path 2: Config Connector (KCC)

**Prerequisites:** A running GKE cluster with Config Connector installed.

```bash
cd templates/gke-fqdn-egress-security/config-connector

# Apply infrastructure manifests
kubectl apply -n forge-management -f .

# Wait for readiness
kubectl wait -n forge-management --for=condition=Ready --all --timeout=3600s -f .

# Get credentials
gcloud container clusters get-credentials gke-fqdn-egress-kcc --region us-central1

# Deploy workload
kubectl apply -f ../config-connector-workload/
```

**Cleanup:**
```bash
kubectl delete -f ../config-connector-workload/
kubectl delete -n forge-management -f . --wait=true --timeout=900s
```

---

## Verification

After deploying with either path, run the validation script:

```bash
export PROJECT_ID="YOUR_PROJECT_ID"
export CLUSTER_NAME="gke-fqdn-egress-tf" # or gke-fqdn-egress-kcc
export REGION="us-central1"
chmod +x templates/gke-fqdn-egress-security/validate.sh
./templates/gke-fqdn-egress-security/validate.sh
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `gke-fqdn-egress-tf` |
| `network_name` | VPC network name | `gke-fqdn-egress-tf-vpc` |
