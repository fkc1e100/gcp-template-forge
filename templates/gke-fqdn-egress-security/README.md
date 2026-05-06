# GKE Zero-Trust FQDN Egress

> Zero-trust egress security with FQDN network policies for controlling AI API traffic from GKE

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Architecture

This template demonstrates how to implement zero-trust egress security in GKE using FQDN-based network policies. This is a GKE Enterprise feature that allows you to restrict outbound traffic from your pods to specific, approved domains (FQDNs) rather than relying on unstable IP addresses.

The architecture includes a private GKE cluster with Dataplane V2 enabled, which is a prerequisite for FQDN network policies. The cluster is registered to a Fleet to enable GKE Enterprise capabilities. A sample `FQDNNetworkPolicy` is provided that allows access to Anthropic and Hugging Face APIs while blocking all other outbound traffic.

This template provisions:

- **VPC Network** — Dedicated VPC with a primary subnet in `us-central1`
- **GKE Cluster** — Standard cluster (`gke-fqdn-egress`) with 1x e2-standard-4 Spot node pool
- **Workload** — A test pod using `curl` to verify FQDN-based egress restrictions.

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
| Standard (Spot) Node Pool (1x e2-standard-4) | ~$75 |
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
Starting GKE FQDN Network Policy Validation Tests...
Test 1: Cluster Connectivity... Connectivity passed.
Test 2: Verifying Dataplane V2 and FQDN Policy Enablement... Dataplane V2 and FQDN Policy enablement validated.
Test 3: Verifying FQDNNetworkPolicy Resource... FQDNNetworkPolicy resource found and verified.
Test 4: Waiting for Egress Verifier Pod... Verifier pod is ready.
Test 5: Running Egress Tests...
Testing domain: anthropic.com (Expected: true)...
SUCCESS: anthropic.com is reachable (attempt 1).
...
Test 5: Running Egress Tests... SUCCESS: google.com is blocked as expected (attempt 1).
All GKE FQDN Network Policy Validation Tests passed successfully!
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
| `service_account` | The service account to use for the GKE nodes | required |
