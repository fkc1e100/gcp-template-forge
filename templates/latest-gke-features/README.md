# Latest GKE Features

> Showcase of latest GKE features: Gateway API, Node Auto-Provisioning, and modern workload patterns

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Architecture

This template demonstrates some of the latest and most advanced features of Google Kubernetes Engine (GKE). It showcases both cluster-level infrastructure improvements and modern workload deployment patterns.

Key features included:
- **GKE Gateway API**: Enabled by default (`CHANNEL_STANDARD`), providing a modern, expressive way to manage load balancing.
- **Node Pool Auto-provisioning (NAP)**: Automatically creates and manages node pools based on workload requirements.
- **Image Streaming (GCFS)**: Significantly reduces container startup times by streaming image data on-demand.
- **Enterprise Security Posture**: Advanced vulnerability scanning and security monitoring (Vulnerability Enterprise).
- **Native Sidecar Containers**: Leveraging Kubernetes 1.29+ "Sidecar Containers" feature (init containers with `restartPolicy: Always`).
- **Pod Topology Spread Constraints**: Modern scheduling to ensure high availability across hostnames and zones.

This template provisions:

- **VPC Network** — Dedicated VPC with a primary subnet in `us-central1`
- **GKE Cluster** — Standard regional cluster (`latest-gke-features`) with Spot VM Node Pool
- **Workload** — Nginx deployment with native sidecar and GKE Gateway exposure

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `latest-gke-features-<uid>-tf` | `latest-gke-features-<uid>-kcc` |
| VPC Network | `latest-gke-features-<uid>-tf-vpc` | `latest-gke-features-<uid>-kcc-vpc` |
| Subnet | `latest-gke-features-<uid>-tf-subnet` | `latest-gke-features-<uid>-kcc-subnet` |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| Spot VM Node Pool (3x e2-standard-4) | ~$90 |
| GKE Gateway (L7 Load Balancer) | ~$18 |
| **Total** | **~$183** |

*Estimates based on sustained use in us-central1. Spot VMs and Gateway usage may vary.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/latest-gke-features/terraform-helm

# Initialize with GCS backend (or use local state for testing)
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="prefix=latest-gke-features/terraform-helm"

# Review the plan
terraform plan \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="region=us-central1" \
  -var="service_account=YOUR_SERVICE_ACCOUNT"

# Apply (provisions GKE cluster and supporting infrastructure)
terraform apply \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="region=us-central1" \
  -var="service_account=YOUR_SERVICE_ACCOUNT"

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
terraform destroy \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="region=us-central1" \
  -var="service_account=YOUR_SERVICE_ACCOUNT"
```

---

### Path 2: Config Connector (KCC)

**Prerequisites:** A running GKE cluster with Config Connector installed. See the
[KCC installation guide](https://cloud.google.com/config-connector/docs/how-to/install-upgrade-uninstall).
The `forge-management` namespace must have a `ConfigConnectorContext` pointing to a
service account with `roles/container.admin` and `roles/compute.networkAdmin`.

```bash
cd templates/latest-gke-features/config-connector

# Apply the GCP infrastructure manifests
kubectl apply -n forge-management -f .

# Wait for all resources to be Ready (GKE cluster takes ~10 minutes)
kubectl wait -n forge-management --for=condition=Ready --all \
  --timeout=3600s -f .

# Get cluster credentials (once ContainerCluster is Ready)
CLUSTER_NAME=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template=latest-gke-features" \
  -o jsonpath='{.items[0].metadata.name}')
LOCATION=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template=latest-gke-features" \
  -o jsonpath='{.items[0].spec.location}')
gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${LOCATION}"

# Deploy the workload
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

---

## Verification

After deploying with either path, run the validation script to confirm end-to-end functionality:

```bash
export PROJECT_ID="YOUR_PROJECT_ID"
export CLUSTER_NAME="<cluster-name-from-outputs>"
export REGION="us-central1"
chmod +x templates/latest-gke-features/validate.sh
./templates/latest-gke-features/validate.sh
```

Expected output:
```
Test 1: Cluster Connectivity... Connectivity passed.
Test 2: Workload Readiness... Workload is available.
Test 3: Native Sidecar Validation... Native Sidecar validated (restartPolicy: Always found).
Test 4: Gateway API Validation... Gateway endpoint test passed!
Test 5: Image Streaming Check... Image Streaming (GCFS) validated.
Test 6: Node Pool Auto-provisioning (NAP) Check... Node Pool Auto-provisioning (NAP) validated.
Test 7: Security Posture Check... Security Posture validated (Enterprise Vulnerability scanning enabled).
All Latest GKE Features Validation Tests passed successfully!
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
| `service_account`| Node service account | required |
