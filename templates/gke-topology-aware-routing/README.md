# GKE Topology-Aware Routing

> Optimize cross-zone egress costs in GKE using Topology-Aware Routing.

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Architecture

Topology-Aware Routing optimizes cross-zone egress costs by preferring same-zone traffic. In multi-zonal GKE clusters, network traffic between pods in different zones incurs egress charges. This template uses Topology-Aware Hints to keep traffic local to the zone where possible.

Key features include Gateway API enablement, Topology Spread Constraints for even workload distribution, and Service Topology hints (`service.kubernetes.io/topology-mode: Auto`).

This template provisions:

- **VPC Network** — Dedicated VPC with a primary subnet in `us-central1`
- **GKE Cluster** — Regional cluster (`gke-topology-aware-routing`) with Gateway API enabled.
- **Workload** — Frontend and Backend microservices with Topology-Aware Hints enabled.

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `gke-topology-aware-routing-tf` | `gke-topology-aware-routing-kcc` |
| VPC Network | `gke-topology-aware-routing-vpc` | `gke-topology-aware-routing-kcc-vpc` |
| Subnet | `gke-topology-aware-routing-subnet` | `gke-topology-aware-routing-kcc-subnet` |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| Spot Node Pool (3x e2-standard-4) | ~$90 |
| **Total** | **~$165** |

*Estimates based on sustained use in us-central1. GPU templates incur additional on-demand charges.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/gke-topology-aware-routing/terraform-helm

# Initialize with GCS backend (or use local state for testing)
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="prefix=gke-topology-aware-routing/terraform-helm"

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
cd templates/gke-topology-aware-routing/config-connector

# Apply the GCP infrastructure manifests
kubectl apply -n forge-management -f .

# Wait for all resources to be Ready (GKE cluster takes ~10 minutes)
kubectl wait -n forge-management --for=condition=Ready --all \
  --timeout=3600s -f .

# Get cluster credentials (once ContainerCluster is Ready)
CLUSTER_NAME=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template=gke-topology-aware-routing" \
  -o jsonpath='{.items[0].metadata.name}')
LOCATION=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template=gke-topology-aware-routing" \
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
chmod +x templates/gke-topology-aware-routing/validate.sh
./templates/gke-topology-aware-routing/validate.sh
```

Expected output:
```
Test 1: Cluster Connectivity... Connectivity passed.
Test 2: Node Readiness... All nodes are Ready.
Test 3: Workload Readiness... Workload is available.
All GKE Topology-Aware Routing Validation Tests passed successfully!
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `gke-topology-aware-routing-tf` |
| `network_name` | VPC network name | `gke-topology-aware-routing-vpc` |
| `subnet_name` | Subnet name | `gke-topology-aware-routing-subnet` |
