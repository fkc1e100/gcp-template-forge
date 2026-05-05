# Basic GKE Hello World

> A minimal GKE Standard cluster with a Hello World workload, deployable via Terraform + Helm or Config Connector.

## Architecture

This template provides a foundational GKE Standard architecture. It includes a VPC with secondary ranges for Pods and Services, a regional GKE Standard cluster with a single Spot node pool for cost-efficiency, and a simple Hello World workload exposed via a LoadBalancer.

This template provisions:

- **VPC Network** — Dedicated VPC with a primary subnet in `us-central1`
- **GKE Cluster** — Standard cluster (`gke-basic`) with 1x e2-standard-2 Spot node pool
- **Workload** — Hello World workload (Google's `hello-app` container)

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `gke-basic-<uid>-tf` | `basic-gke-hello-world-<uid>` |
| VPC Network | `gke-basic-<uid>-tf-vpc` | `basic-gke-hello-world-<uid>-vpc` |
| Subnet | `gke-basic-<uid>-tf-subnet` | `basic-gke-hello-world-<uid>-subnet` |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| Spot Node Pool (1x e2-standard-2) | ~$15 |
| LoadBalancer & Networking | ~$18 |
| **Total** | **~$108** |

*Estimates based on sustained use in us-central1. GPU templates incur additional on-demand charges.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/basic-gke-hello-world/terraform-helm

# Initialize with GCS backend (or use local state for testing)
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="prefix=basic-gke-hello-world/terraform-helm"

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

**Prerequisites:** A running GKE cluster with Config Connector installed. See the
[KCC installation guide](https://cloud.google.com/config-connector/docs/how-to/install-upgrade-uninstall).
The `forge-management` namespace must have a `ConfigConnectorContext` pointing to a
service account with `roles/container.admin` and `roles/compute.networkAdmin`.

```bash
cd templates/basic-gke-hello-world/config-connector

# Apply the GCP infrastructure manifests
kubectl apply -n forge-management -f .

# Wait for all resources to be Ready (GKE cluster takes ~10 minutes)
kubectl wait -n forge-management --for=condition=Ready --all \
  --timeout=3600s -f .

# Get cluster credentials (once ContainerCluster is Ready)
CLUSTER_NAME=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template=basic-gke-hello-world" \
  -o jsonpath='{.items[0].metadata.name}')
LOCATION=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template=basic-gke-hello-world" \
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
chmod +x templates/basic-gke-hello-world/validate.sh
./templates/basic-gke-hello-world/validate.sh
```

Expected output:
```
Test 1: Cluster Connectivity... Connectivity passed.
Test 2: Node Readiness... All nodes are Ready.
Test 3: Workload Readiness... Workload is available.
All Validation Tests passed successfully for basic-gke-hello-world!
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `gke-basic-tf` |
| `network_name` | VPC network name | `gke-basic-tf-vpc` |
| `subnet_name` | Subnet name | `gke-basic-tf-subnet` |

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Validation Record

|  | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | success | pending |
| **Date** | 2026-04-20 | 2026-04-20 |
| **Duration** | 10m 15s | 15m 20s |
| **Region** | us-central1 | us-central1 (regional) |
| **Zones** | us-central1-a,us-central1-b,us-central1-c,us-central1-f | us-central1 (regional) |
| **Cluster** | gke-basic-tf | basic-gke-hello-world |
| **Agent tokens** | not recorded | (shared session) |
| **Estimated cost** | - | -- |
| **Commit** | multiple | pending |
