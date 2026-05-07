# Multi-Tenant Ray on GKE

> Multi-Tenant Ray on GKE with Equitable Queuing using KubeRay and Kueue


## Architecture

This template demonstrates how to solve the "Noisy Neighbor" problem for shared GPU clusters using the KubeRay Operator and the Kueue Operator.

This template provisions:

- **VPC + Subnet** — VPC with secondary CIDR ranges for pods and services.
- **GKE Standard** — A cluster featuring an autoscaled GPU node pool (using L4 GPUs via `g2-standard-4` spot instances) and a standard system node pool.
- **KubeRay Operator** — Manages the lifecycle of Ray clusters on Kubernetes.
- **Kueue Operator** — Cloud-native job queueing and equitable resource sharing.
- **Workloads** — Two namespaces (`team-a` and `team-b`), each with a Kueue `LocalQueue` linked to a `ClusterQueue` sharing a single GPU `Cohort`. Kueue ensures that if Team A requests excess GPUs, their pods remain in a pending state until Team B finishes their work.

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `gke-kuberay-kueue-<uid>-tf` | `gke-kuberay-kueue-<uid>-kcc` |
| VPC Network | `gke-kuberay-kueue-<uid>-tf-vpc` | `gke-kuberay-kueue-<uid>-kcc-vpc` |
| Subnet | `gke-kuberay-kueue-<uid>-tf-subnet` | `gke-kuberay-kueue-<uid>-kcc-subnet` |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| GPU Node Pool (5x g2-standard-4 spot) | ~$150 |
| **Total** | **~$225** |

*Estimates based on sustained use in us-central1. GPU templates incur additional on-demand charges.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/kuberay-kueue/terraform-helm

# Initialize with GCS backend (or use local state for testing)
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="prefix=kuberay-kueue/terraform-helm"

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
terraform destroy -var="project_id=YOUR_PROJECT_ID" -var="region=us-central1" -var="service_account=YOUR_SERVICE_ACCOUNT"
```

---

### Path 2: Config Connector (KCC)

**Prerequisites:** A running GKE cluster with Config Connector installed. See the
[KCC installation guide](https://cloud.google.com/config-connector/docs/how-to/install-upgrade-uninstall).
The `forge-management` namespace must have a `ConfigConnectorContext` pointing to a
service account with `roles/container.admin` and `roles/compute.networkAdmin`.

```bash
cd templates/kuberay-kueue/config-connector

# Apply the GCP infrastructure manifests
kubectl apply -n forge-management -f .

# Wait for all resources to be Ready (GKE cluster takes ~10 minutes)
kubectl wait -n forge-management --for=condition=Ready --all \
  --timeout=3600s -f .

# Get cluster credentials (once ContainerCluster is Ready)
CLUSTER_NAME=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template=gke-kuberay-kueue-multitenant" \
  -o jsonpath='{.items[0].metadata.name}')
LOCATION=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template=gke-kuberay-kueue-multitenant" \
  -o jsonpath='{.items[0].spec.location}')
gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${LOCATION}"

# Deploy the workload
kubectl apply -n default --server-side -f ../config-connector-workload/

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

- **Queued Provisioning**: Not supported in KCC v1beta1 ContainerNodePool. The Terraform path
  uses `queued_provisioning` for this capability. Tracked upstream:
  https://github.com/GoogleCloudPlatform/k8s-config-connector/issues/TBD

---

## Verification

After deploying with either path, run the validation script to confirm end-to-end functionality:

```bash
export PROJECT_ID="YOUR_PROJECT_ID"
export CLUSTER_NAME="<cluster-name-from-outputs>"
export REGION="us-central1"
chmod +x templates/kuberay-kueue/validate.sh
./templates/kuberay-kueue/validate.sh
```

Expected output:
```
Test 1: Cluster Connectivity... Connectivity passed.
Test 2: Node Readiness... All nodes are Ready.
Test 3: Workload Readiness... Workload is available.
All Validation Tests passed successfully for Multi-Tenant Ray on GKE!
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `zone` | GCP zone | `us-central1-c` |
| `cluster_name` | GKE cluster name | `gke-kuberay-kueue` |
| `network_name` | VPC network name | `gke-kuberay-kueue-vpc` |
| `subnet_name` | Subnet name | `gke-kuberay-kueue-subnet` |
| `service_account` | Node service account | required |
| `uid_suffix` | Unique suffix for resource names | `""` |

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->
