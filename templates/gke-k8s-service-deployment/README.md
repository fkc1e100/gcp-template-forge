# K8s Service Deployment

> A template for deploying a simple web service on GKE with a LoadBalancer.

## Architecture

This template provisions a complete environment for a web service, including the networking infrastructure, a GKE cluster, and the workload itself.

This template provisions:

- **VPC Network** — Dedicated VPC with a primary subnet in `us-central1`
- **GKE Cluster** — Standard cluster (`k8s-svc-lb`) with a single spot e2-medium node
- **Workload** — an Nginx web service exposed via a LoadBalancer

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `k8s-svc-lb-<uid>-tf` | `k8s-svc-lb-<uid>-kcc` |
| VPC Network | `k8s-svc-lb-<uid>-tf-vpc` | `k8s-svc-lb-<uid>-kcc-vpc` |
| Subnet | `k8s-svc-lb-<uid>-tf-subnet` | `k8s-svc-lb-<uid>-kcc-subnet` |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| e2-medium Node Pool (1x e2-medium) | ~$25 |
| **Total** | **~$100** |

*Estimates based on sustained use in us-central1. Actual costs may vary based on usage and discounts.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/k8s-service-deployment/terraform-helm

# Initialize with GCS backend (or use local state for testing)
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="prefix=k8s-service-deployment/terraform-helm"

# Review the plan
terraform plan \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="cluster_name=k8s-svc-lb-tf" \
  -var="network_name=k8s-svc-lb-tf-vpc" \
  -var="subnet_name=k8s-svc-lb-tf-subnet"

# Apply
terraform apply \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="cluster_name=k8s-svc-lb-tf" \
  -var="network_name=k8s-svc-lb-tf-vpc" \
  -var="subnet_name=k8s-svc-lb-tf-subnet"

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
  -var="cluster_name=k8s-svc-lb-tf" \
  -var="network_name=k8s-svc-lb-tf-vpc" \
  -var="subnet_name=k8s-svc-lb-tf-subnet"
```

---

### Path 2: Config Connector (KCC)

**Prerequisites:** A running GKE cluster with Config Connector installed.

```bash
cd templates/k8s-service-deployment/config-connector

# Apply the GCP infrastructure manifests
kubectl apply -n forge-management -f .

# Wait for all resources to be Ready (GKE cluster takes ~10 minutes)
kubectl wait -n forge-management --for=condition=Ready --all \
  --timeout=3600s -f .

# Get cluster credentials
CLUSTER_NAME=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template=k8s-svc-lb" \
  -o jsonpath='{.items[0].metadata.name}')
LOCATION=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template=k8s-svc-lb" \
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
export CLUSTER_NAME="k8s-svc-lb-tf"
export REGION="us-central1"
chmod +x templates/k8s-service-deployment/validate.sh
./templates/k8s-service-deployment/validate.sh
```

Expected output:
```
Test 1: Cluster Connectivity... Connectivity passed.
Test 2: Node Readiness... All nodes are Ready.
Test 3: Workload Readiness... Workload is available.
Test 4: Endpoint Interaction... Endpoint test passed!
All Validation Tests passed successfully for K8s Service Deployment!
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `k8s-svc-lb-tf` |
| `network_name` | VPC network name | `k8s-svc-lb-tf-vpc` |
| `subnet_name` | Subnet name | `k8s-svc-lb-tf-subnet` |

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Validation Record

|  | Terraform + Helm | Config Connector |
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
