# GKE Zero-Trust FQDN Egress

> Zero-trust egress security with FQDN network policies for controlling AI API traffic from GKE

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Architecture

This template demonstrates how to implement zero-trust egress security in GKE using **FQDN Network Policies**.
Traditional Kubernetes Network Policies are restricted to IP addresses or CIDR blocks, which is difficult
to manage for dynamic cloud services. GKE Dataplane V2 allows you to define policies based on Fully Qualified
Domain Names (FQDNs), ensuring that workloads can only communicate with approved external APIs.

The architecture includes:
- **Private GKE Cluster** with Dataplane V2 enabled and FQDN policy support.
- **Cloud NAT** for secure outbound connectivity without exposing nodes to the public internet.
- **GKE Enterprise (Fleet)** registration to enable advanced security features.
- **FQDN Network Policies** that whitelist specific domains (e.g., `openai.com`, `googleapis.com`).

This template provisions:

- **VPC Network** — Dedicated VPC with a primary subnet in `us-central1`
- **GKE Cluster** — Private cluster (`gke-fqdn-egress`) with one spot node pool using e2-standard-4 instances
- **Workload** — a verification pod and FQDN network policies

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `gke-fqdn-egress-<uid>-tf` | `gke-fqdn-egress-<uid>-kcc` |
| VPC Network | `gke-fqdn-egress-<uid>-tf-vpc` | `gke-fqdn-egress-<uid>-kcc-vpc` |
| Subnet | `gke-fqdn-egress-<uid>-tf-subnet` | `gke-fqdn-egress-<uid>-kcc-subnet` |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| Spot Node Pool (1x e2-standard-4) | ~$75 |
| **Total** | **~$150** |

*Estimates based on sustained use in us-central1. GPU templates incur additional on-demand charges.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/gke-fqdn-egress-security/terraform-helm

# Initialize with GCS backend (or use local state for testing)
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="prefix=gke-fqdn-egress-security/terraform-helm"

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
cd templates/gke-fqdn-egress-security/config-connector

# Apply the GCP infrastructure manifests
kubectl apply -n forge-management -f .

# Wait for all resources to be Ready (GKE cluster takes ~10 minutes)
kubectl wait -n forge-management --for=condition=Ready --all \
  --timeout=3600s -f .

# Get cluster credentials (once ContainerCluster is Ready)
CLUSTER_NAME=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template=gke-fqdn-egress" \
  -o jsonpath='{.items[0].metadata.name}')
LOCATION=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template=gke-fqdn-egress" \
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
chmod +x templates/gke-fqdn-egress-security/validate.sh
./templates/gke-fqdn-egress-security/validate.sh
```

Expected output:
```
Test 1: Cluster Connectivity... Connectivity passed.
Test 2: Node Readiness... All nodes are Ready.
Test 3: Workload Readiness... Workload is available.
All Validation Tests passed successfully for GKE Zero-Trust FQDN Egress!
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `gke-fqdn-egress-tf` |
| `network_name` | VPC network name | `gke-fqdn-egress-tf-vpc` |
| `subnet_name` | Subnet name | `gke-fqdn-egress-tf-subnet` |
| `service_account` | GKE node pool service account | required |
