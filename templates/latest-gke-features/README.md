# Latest GKE Features

> Showcase of latest GKE features: Gateway API, Node Auto-Provisioning, and modern workload patterns

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Architecture

This template demonstrates some of the latest and most advanced features of Google Kubernetes Engine (GKE). It showcases both cluster-level infrastructure improvements and modern workload deployment patterns like Gateway API and Node Pool Auto-provisioning.

This template provisions:

- **VPC Network** — VPC-native network configured for private clusters.
- **GKE Cluster** — GKE Standard cluster (`latest-gke-feat`) with Gateway API and Node Pool Auto-provisioning (NAP) enabled.
- **Workload** — Modern workload utilizing Native Sidecar Containers and exposed via GKE Gateway.

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `latest-gke-feat-<uid>-tf` | `latest-gke-feat-<uid>-kcc` |
| VPC Network | `latest-gke-feat-<uid>-tf-vpc` | `latest-gke-feat-<uid>-kcc-vpc` |
| Subnet | `latest-gke-feat-<uid>-tf-subnet` | `latest-gke-feat-<uid>-kcc-subnet` |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| E2 Standard Node Pool (1x e2-standard-4 Spot) | ~$29 |
| Load Balancer (Gateway API) | ~$18 |
| **Total** | **~$122** |

*Estimates based on sustained use in us-central1 with Spot nodes.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/latest-gke-features/terraform-helm

# Initialize
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="prefix=templates/latest-gke-features/terraform-helm"

# Apply
terraform apply -var="project_id=YOUR_PROJECT_ID"

# Get credentials
gcloud container clusters get-credentials latest-gke-feat-tf --region us-central1

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
cd templates/latest-gke-features/config-connector

# Apply infrastructure manifests
kubectl apply -n forge-management -f .

# Wait for readiness
kubectl wait -n forge-management --for=condition=Ready --all --timeout=3600s -f .

# Get credentials
gcloud container clusters get-credentials latest-gke-feat-kcc --region us-central1

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
export CLUSTER_NAME="latest-gke-feat-tf" # or latest-gke-feat-kcc
export REGION="us-central1"
chmod +x templates/latest-gke-features/validate.sh
./templates/latest-gke-features/validate.sh
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `latest-gke-feat-tf` |
| `network_name` | VPC network name | `latest-gke-feat-tf-vpc` |
