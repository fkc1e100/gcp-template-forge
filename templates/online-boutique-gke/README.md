# Online Boutique - Microservices Demo

> Deploy 11 microservices on a GKE Standard Cluster

## Architecture

This template deploys the standard Google Cloud Online Boutique microservices demo. It spins up an 11-tier microservices application running on Google Kubernetes Engine (GKE) to demonstrate a complete, functional e-commerce platform. The application includes frontend, checkout, cart, and recommendations services among others, and utilizes in-cluster Redis for cart data storage.

This template provision:

- **VPC Network** — Dedicated VPC with a primary subnet in `us-central1`
- **GKE Cluster** — Standard GKE cluster (`online-boutique-gke`) with a regional node pool spanning 3 zones
- **Workload** — 11 Microservices including an external LoadBalancer for the frontend

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `online-boutique-gke-<uid>-tf` | `online-boutique-gke-<uid>-kcc` |
| VPC Network | `online-boutique-gke-<uid>-tf-vpc` | `online-boutique-gke-<uid>-kcc-vpc` |
| Subnet | `online-boutique-gke-<uid>-tf-subnet` | `online-boutique-gke-<uid>-kcc-subnet` |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| Standard Node Pool (2x e2-standard-4) | ~$100 |
| **Total** | **~$175** |

*Estimates based on sustained use in us-central1. GPU templates incur additional on-demand charges.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/online-boutique-gke/terraform-helm

# Initialize with GCS backend (or use local state for testing)
terraform init 
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" 
  -backend-config="prefix=online-boutique-gke/terraform-helm"

# Review the plan
terraform plan 
  -var="project_id=YOUR_PROJECT_ID" 
  -var="region=us-central1"

# Apply (provisions GKE cluster and supporting infrastructure)
terraform apply 
  -var="project_id=YOUR_PROJECT_ID" 
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
cd templates/online-boutique-gke/config-connector

# Apply the GCP infrastructure manifests
kubectl apply -n forge-management -f .

# Wait for all resources to be Ready (GKE cluster takes ~10 minutes)
kubectl wait -n forge-management --for=condition=Ready --all 
  --timeout=3600s -f .

# Get cluster credentials (once ContainerCluster is Ready)
CLUSTER_NAME=$(kubectl get containerclusters.container.cnrm.cloud.google.com 
  -n forge-management -l "template=online-boutique-gke" 
  -o jsonpath='{.items[0].metadata.name}')
LOCATION=$(kubectl get containerclusters.container.cnrm.cloud.google.com 
  -n forge-management -l "template=online-boutique-gke" 
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

### KCC Limitations

- **subnetwork_labels**: Not supported in KCC v1beta1 ComputeSubnetwork. The Config Connector templates omit the labels.
- **network_policy_config_provider_calico**: Not supported in KCC ContainerCluster.

---

## Verification

After deploying with either path, run the validation script to confirm end-to-end functionality:

```bash
export PROJECT_ID="YOUR_PROJECT_ID"
export CLUSTER_NAME="<cluster-name-from-outputs>"
export REGION="us-central1"
chmod +x templates/online-boutique-gke/validate.sh
./templates/online-boutique-gke/validate.sh
```

Expected output:
```
Test 1: Cluster Connectivity... Connectivity passed.
Test 2: Node Readiness... All nodes are Ready.
Test 3: Workload Readiness... Workload is available.
All Validation Tests passed successfully for Online Boutique
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `online-boutique-gke-tf` |
| `network_name` | VPC network name | `online-boutique-gke-tf-vpc` |
| `subnet_name` | Subnet name | `online-boutique-gke-tf-subnet` |

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
