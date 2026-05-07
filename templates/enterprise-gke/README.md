# Enterprise GKE Cluster

> Enterprise-grade GKE with Binary Authorization, Workload Identity, and hardened security controls

## Architecture

This template provides an enterprise-grade Google Kubernetes Engine (GKE) architecture with security hardening. It enables Binary Authorization in enforce mode, uses Workload Identity for secure GCP access, and includes advanced security posture monitoring. **Warning:** Binary Authorization requires a project-level policy; otherwise, pod deployments may be blocked.

This template provisions:

- **VPC Network** — Dedicated VPC with a primary subnet in `us-central1`
- **GKE Cluster** — GKE Standard cluster (`enterprise-gke`) with e2-standard-4 spot node pool and advanced security features
- **Workload** — Nginx-based production-ready workload with Workload Identity and External Load Balancer

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `enterprise-gke-<uid>-tf` | `enterprise-gke-<uid>-kcc` |
| VPC Network | `enterprise-gke-<uid>-tf-vpc` | `enterprise-gke-<uid>-kcc-vpc` |
| Subnet | `enterprise-gke-<uid>-tf-subnet` | `enterprise-gke-<uid>-kcc-subnet` |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| E2-standard-4 Node Pool (1x e2-standard-4 Spot) | ~$54 |
| External Load Balancer | Forwarding Rule + traffic | ~$18 |
| **Total** | **~$147** |

*Estimates based on sustained use in us-central1. GPU templates incur additional on-demand charges.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/enterprise-gke/terraform-helm

# Initialize with GCS backend (or use local state for testing)
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="prefix=enterprise-gke/terraform-helm"

# Review the plan
terraform plan \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="region=us-central1" \
  -var="create_service_accounts=true"

# Apply (provisions GKE cluster and supporting infrastructure)
terraform apply \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="region=us-central1" \
  -var="create_service_accounts=true"

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
cd templates/enterprise-gke/config-connector

# Apply the GCP infrastructure manifests
kubectl apply -n forge-management -f .

# Wait for all resources to be Ready (GKE cluster takes ~10 minutes)
kubectl wait -n forge-management --for=condition=Ready --all \
  --timeout=3600s -f .

# Get cluster credentials (once ContainerCluster is Ready)
CLUSTER_NAME=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template=enterprise-gke" \
  -o jsonpath='{.items[0].metadata.name}')
LOCATION=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template=enterprise-gke" \
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

- **Network Policy Provider**: Not supported in KCC v1beta1 ContainerCluster. The Terraform path
  uses `network_policy.provider = "CALICO"`. This template uses `spec.datapathProvider: ADVANCED_DATAPATH`
  in KCC to enable equivalent GKE Dataplane V2 network policy enforcement. Tracked upstream:
  https://github.com/GoogleCloudPlatform/k8s-config-connector/issues/TBD

---

## Verification

After deploying with either path, run the validation script to confirm end-to-end functionality:

```bash
export PROJECT_ID="YOUR_PROJECT_ID"
export CLUSTER_NAME="<cluster-name-from-outputs>"
export REGION="us-central1"
chmod +x templates/enterprise-gke/validate.sh
./templates/enterprise-gke/validate.sh
```

Expected output:
```
Test 1: Cluster Connectivity... Connectivity passed.
Test 2: Node Readiness... All nodes are Ready.
Test 3: Workload Readiness... Workload is available.
Test 4: Workload Identity Integration... Workload Identity validated.
Test 5: Endpoint Interaction... Endpoint test passed!
All Validation Tests passed successfully for Enterprise GKE Cluster!
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `enterprise-gke-tf` |
| `network_name` | VPC network name | `enterprise-gke-tf-vpc` |
| `subnet_name` | Subnet name | `enterprise-gke-tf-subnet` |
| `create_service_accounts` | Whether to create dedicated SAs | `false` |
| `service_account` | Node SA (required if create_service_accounts=false) | required |
| `workload_service_account` | Workload Identity SA | optional |

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

