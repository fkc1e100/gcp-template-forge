# Latest GKE Features

> Showcase of latest GKE features: Gateway API, Node Auto-Provisioning, and modern workload patterns

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Architecture

This template demonstrates a modern GKE environment leveraging the latest platform capabilities released in 2024, 2025, and 2026.

The architecture includes:
- **VPC Network** — A private VPC-native network with dedicated subnets for GKE nodes, pods, and services.
- **GKE Cluster** — A GKE Standard cluster on the **RAPID** release channel, enabling:
    - **Gateway API**: Modern, expressive load balancing using `Gateway` and `HTTPRoute` resources.
    - **Node Pool Auto-provisioning (NAP)**: Automatically creates and manages node pools based on workload requirements (CPU, Memory, Spot).
    - **Image Streaming (GCFS)**: Significantly reduces container startup times by streaming image data on-demand.
    - **Enterprise Security Posture**: Advanced vulnerability scanning and security monitoring (Vulnerability Enterprise).
- **Workload** — A sample application showcasing:
    - **Native Sidecar Containers**: Leveraging Kubernetes 1.29+ "Sidecar Containers" feature (init containers with `restartPolicy: Always`).
    - **Pod Topology Spread Constraints**: Modern scheduling to ensure high availability across hostnames and zones.

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
| Node Pool (e2-standard-4, Spot) | ~$125 |
| **Total** | **~$200** |

*Estimates based on sustained use in us-central1. Spot VM pricing varies by region and availability.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/latest-gke-features/terraform-helm

# Initialize with GCS backend
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="prefix=latest-gke-features/terraform-helm"

# Apply (provisions GKE cluster and supporting infrastructure)
terraform apply -var="project_id=YOUR_PROJECT_ID"

# Get cluster credentials
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw cluster_location)
gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${REGION}"

# Deploy the workload via Helm
helm upgrade --install release ./workload --wait --timeout=30m

# Verify
./../validate.sh
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

# Apply the GCP infrastructure manifests
kubectl apply -n forge-management -f .

# Wait for all resources to be Ready (GKE cluster takes ~10 minutes)
kubectl wait -n forge-management --for=condition=Ready --all --timeout=3600s -f .

# Get cluster credentials
CLUSTER_NAME=$(kubectl get containerclusters.container.cnrm.cloud.google.com -n forge-management -l "template=latest-gke-features" -o jsonpath='{.items[0].metadata.name}')
LOCATION=$(kubectl get containerclusters.container.cnrm.cloud.google.com -n forge-management -l "template=latest-gke-features" -o jsonpath='{.items[0].spec.location}')
gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${LOCATION}"

# Deploy the workload
kubectl apply -n default -f ../config-connector-workload/

# Verify
./../validate.sh
```

**Cleanup:**
```bash
kubectl delete -n default -f ../config-connector-workload/
kubectl delete -n forge-management -f . --wait=true --timeout=900s
```

---

## Verification

After deploying with either path, run the validation script to confirm end-to-end functionality:

```bash
export PROJECT_ID="YOUR_PROJECT_ID"
export CLUSTER_NAME="<cluster-name>"
export REGION="us-central1"
./templates/latest-gke-features/validate.sh
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `latest-gke-features-tf` |
| `network_name` | VPC network name | `latest-gke-features-tf-vpc` |
| `subnet_name` | Subnet name | `latest-gke-features-tf-subnet` |
| `service_account` | Node pool service account | required |

|  | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | success | success |
| **Date** | 2026-04-19 | 2026-04-19 |
