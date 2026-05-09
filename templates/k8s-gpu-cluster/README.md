# GKE GPU Cluster Template

This template deploys a GKE cluster with an N1-standard-4 node pool equipped with an NVIDIA T4 GPU.

## Architecture

This template provisions a GKE Standard cluster with a specialized GPU node pool.

- **VPC Network** — Uses the `default` VPC network.
- **GKE Cluster** — A GKE Standard cluster with Vertical Pod Autoscaling enabled.
- **GPU Node Pool** — A single-node pool using `n1-standard-4` machines, each equipped with one NVIDIA Tesla T4 GPU.
- **Workload** — A test Pod running `nvidia-smi` to verify GPU availability.

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| GPU Node Pool (1x n1-standard-4 + 1x T4) | ~$180 |
| **Total** | **~$255** |

*Estimates based on sustained use in us-central1. GPU templates incur additional on-demand charges.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/k8s-gpu-cluster/terraform-helm

# Initialize with GCS backend (or use local state for testing)
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="prefix=k8s-gpu-cluster/terraform-helm"

# Review the plan
terraform plan \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="region=us-central1"

# Apply (provisions GKE cluster and supporting infrastructure)
terraform apply \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="region=us-central1"

# Get cluster credentials
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw cluster_location)
gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${REGION}"

# Deploy the workload via Helm
helm upgrade --install release ./workload --wait --timeout=30m

# Verify
kubectl get nodes
kubectl get pods -A
```

**Cleanup:**
```bash
helm uninstall release
terraform destroy -var="project_id=YOUR_PROJECT_ID" -var="region=us-central1"
```

---

### Path 2: Config Connector (KCC)

**Note:** This template is currently marked as KCC unsupported due to specific GPU node pool configuration requirements not yet fully supported in KCC v1beta1.

---

## Verification

After deploying, run the validation script to confirm end-to-end functionality:

```bash
export PROJECT_ID="YOUR_PROJECT_ID"
export CLUSTER_NAME="<cluster-name-from-outputs>"
export REGION="us-central1"
chmod +x templates/k8s-gpu-cluster/validate.sh
./templates/k8s-gpu-cluster/validate.sh
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `gke-gpu-tf` |
| `network_name` | VPC network name | `gke-gpu-tf-vpc` |
| `subnet_name` | Subnet name | `gke-gpu-tf-subnet` |

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Validation Record

| | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | pending | pending |
| **Date** | n/a | n/a |
| **Duration** | n/a | n/a |
| **Region** | us-central1 | us-central1 (KCC cluster) |
| **Zones** | - | forge-management namespace |
| **Cluster** | -- | krmapihost-kcc-instance |
| **Agent tokens** | - | (shared session) |
| **Estimated cost** | - | -- |
| **Commit** | n/a | n/a |
