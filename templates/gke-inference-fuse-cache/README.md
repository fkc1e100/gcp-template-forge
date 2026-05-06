# GKE GCS FUSE Inference Cache

> High-performance AI inference with GCS FUSE + Local SSD caching for fast model loading on L4 GPUs

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Architecture

This template demonstrates how to achieve high-performance model loading on GKE using **Cloud Storage FUSE** with **Local SSD caching**. This pattern is ideal for AI inference workloads (like vLLM) that need to load large models (100GB+) quickly while minimizing egress costs and Persistent Disk overhead.

By using Local SSDs for the GCS FUSE cache, you achieve reduced TTFT (Time To First Token) as models are loaded at NVMe speeds (GB/s) after the first pull, significant cost savings by eliminating the need for massive `pd-ssd` boot disks, and improved scale-out speed as new pods on the same node benefit from the "warm" cache immediately.

This template provisions:

- **VPC Network** — Dedicated VPC with a primary subnet in `us-central1`
- **GKE Cluster** — Standard cluster (`gke-inf-fuse-cache`) with L4 GPU acceleration
- **Workload** — vLLM/Mock Inference server configured with GCS FUSE CSI driver and Local SSD caching

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `gke-inf-fuse-cache-<uid>-tf` | `gke-inf-fuse-cache-<uid>-kcc` |
| VPC Network | `gke-inf-fuse-cache-<uid>-tf-vpc` | `gke-inf-fuse-cache-<uid>-kcc-vpc` |
| Subnet | `gke-inf-fuse-cache-<uid>-tf-subnet` | `gke-inf-fuse-cache-<uid>-kcc-subnet` |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| G2 Standard Node Pool (1x g2-standard-4 + L4 GPU) | ~$525 |
| **Total** | **~$600** |

*Estimates based on sustained use in us-central1. GPU templates incur additional on-demand charges.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured. GPU Quota for `NVIDIA_L4_GPUS` in `us-central1`.

```bash
cd templates/gke-inference-fuse-cache/terraform-helm

# Initialize with GCS backend (or use local state for testing)
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="prefix=gke-inference-fuse-cache/terraform-helm"

# Review the plan
terraform plan \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="region=us-central1" \
  -var="service_account=YOUR_NODE_SA"

# Apply (provisions GKE cluster and supporting infrastructure)
terraform apply \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="region=us-central1" \
  -var="service_account=YOUR_NODE_SA"

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
terraform destroy -var="project_id=YOUR_PROJECT_ID" -var="region=us-central1" -var="service_account=YOUR_NODE_SA"
```

---

### Path 2: Config Connector (KCC)

**Prerequisites:** A running GKE cluster with Config Connector installed. See the
[KCC installation guide](https://cloud.google.com/config-connector/docs/how-to/install-upgrade-uninstall).
The `forge-management` namespace must have a `ConfigConnectorContext` pointing to a
service account with `roles/container.admin` and `roles/compute.networkAdmin`.

```bash
cd templates/gke-inference-fuse-cache/config-connector

# Apply the GCP infrastructure manifests
kubectl apply -n forge-management -f .

# Wait for all resources to be Ready (GKE cluster takes ~10 minutes)
kubectl wait -n forge-management --for=condition=Ready --all \
  --timeout=3600s -f .

# Get cluster credentials (once ContainerCluster is Ready)
CLUSTER_NAME=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template=gke-inf-fuse-cache" \
  -o jsonpath='{.items[0].metadata.name}')
LOCATION=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template=gke-inf-fuse-cache" \
  -o jsonpath='{.items[0].spec.location}')
gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${LOCATION}"

# Deploy the workload
# Note: Edit ../config-connector-workload/workload.yaml to set your PROJECT_ID and BUCKET_NAME
kubectl apply -n default -f ../config-connector-workload/

# Verify
kubectl get nodes
kubectl get pods -A
```

**Cleanup:**
```bash
kubectl delete -n default -f ../config-connector-workload/
kubectl delete -n forge-management -f . --wait=true --timeout=900s
```

### KCC Limitations

- **Advanced Node Pool Placement**: Not supported in KCC v1beta1 ContainerNodePool. Advanced placement policies (like `COMPACT` placement for colocation) are only available via the Terraform path. Tracked upstream: https://github.com/GoogleCloudPlatform/k8s-config-connector/issues/TBD

---

## Verification

After deploying with either path, run the validation script to confirm end-to-end functionality:

```bash
export PROJECT_ID="YOUR_PROJECT_ID"
export CLUSTER_NAME="<cluster-name-from-outputs>"
export REGION="us-central1"
chmod +x templates/gke-inference-fuse-cache/validate.sh
./templates/gke-inference-fuse-cache/validate.sh
```

Expected output:
```
=== Validation: GKE GCS FUSE Inference Cache ===
Test 1: Cluster Connectivity... Connectivity passed.
Test 2: Node Readiness... All nodes are Ready.
Test 3: GCS FUSE CSI Driver Check... GCS FUSE CSI Driver is enabled.
Test 4: Node Pool Local SSD Check... Node pool has 1 Local SSD(s) for caching.
Test 5: Workload Readiness... Workload is available.
Test 6: Sidecar and Mount Verification... GCS FUSE mount point /models verified.
Test 7: GPU Check... GPU verified: NVIDIA L4
Test 8: vLLM API Health Check... vLLM API is healthy.
All Validation Tests passed successfully for GKE GCS FUSE Inference Cache!
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `gke-inf-fuse-cache-tf` |
| `network_name` | VPC network name | `gke-inf-fuse-cache-tf-vpc` |
| `subnet_name` | Subnet name | `gke-inf-fuse-cache-tf-subnet` |
| `bucket_name` | GCS bucket for model storage | `gke-inf-fuse-cache-bucket` |
| `service_account` | Node pool service account | required |
| `uid_suffix` | Unique suffix for resource names | `""` |
