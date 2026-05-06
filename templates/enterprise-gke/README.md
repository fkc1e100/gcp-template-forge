# Enterprise GKE Cluster

> Enterprise-grade GKE with Binary Authorization, Workload Identity, and hardened security controls

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Architecture

This template provides an enterprise-grade Google Kubernetes Engine (GKE) architecture. It demonstrates two deployment paths: Terraform + Helm for traditional infrastructure-as-code and Config Connector (KCC) for a Kubernetes-native approach to managing GCP resources.

> **Warning: Binary Authorization**
> This template enables Binary Authorization in `PROJECT_SINGLETON_POLICY_ENFORCE` mode. Ensure your GCP project has a Binary Authorization policy configured, otherwise pod deployments may be blocked.

This template provisions:

- **VPC Network** — Private VPC with dedicated secondary ranges for pods and services.
- **GKE Standard Cluster** — VPC-native, private cluster (`enterprise-gke`) with security hardening (Binary Authorization, Security Posture).
- **Node Pool** — E2-standard-4 instances (Spot) with Secure Boot and Integrity Monitoring.
- **Supporting Infra** — Cloud NAT for private egress and Master Authorized Networks for control plane security.

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `enterprise-gke-<uid>-tf` | `enterprise-gke-<uid>-kcc` |
| VPC Network | `enterprise-gke-<uid>-tf-vpc` | `enterprise-gke-<uid>-kcc-vpc` |
| Subnet | `enterprise-gke-<uid>-tf-subnet` | `enterprise-gke-<uid>-kcc-subnet` |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| E2 Standard Node Pool (1x e2-standard-4 Spot) | ~$29 |
| Load Balancer | ~$18 |
| Cloud NAT | ~$3 |
| **Total** | **~$125** |

*Estimates based on sustained use in us-central1 with Spot nodes. On-demand nodes increase cost to ~$175/mo.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/enterprise-gke/terraform-helm

# Initialize
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="prefix=templates/enterprise-gke/terraform-helm"

# Apply
terraform apply \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="service_account=YOUR_NODE_SA" \
  -var="create_service_accounts=true"

# Get credentials
gcloud container clusters get-credentials enterprise-gke-tf --region us-central1

# Deploy workload
helm upgrade --install release ./workload -f ./workload/values.generated.yaml --namespace gke-workload --create-namespace
```

**Cleanup:**
```bash
helm uninstall release -n gke-workload
terraform destroy -var="project_id=YOUR_PROJECT_ID"
```

---

### Path 2: Config Connector (KCC)

**Prerequisites:** A running GKE cluster with Config Connector installed.

```bash
cd templates/enterprise-gke/config-connector

# Apply infrastructure manifests
kubectl apply -n forge-management -f .

# Wait for readiness
kubectl wait -n forge-management --for=condition=Ready --all --timeout=3600s -f .

# Get credentials
gcloud container clusters get-credentials enterprise-gke-kcc --region us-central1

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
export CLUSTER_NAME="enterprise-gke-tf" # or enterprise-gke-kcc
export REGION="us-central1"
chmod +x templates/enterprise-gke/validate.sh
./templates/enterprise-gke/validate.sh
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `enterprise-gke-tf` |
| `network_name` | VPC network name | `enterprise-gke-tf-vpc` |
| `create_service_accounts` | Create dedicated SAs | `false` |
