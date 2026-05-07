# {{DISPLAY_NAME}}

> {{ONE_LINE_DESCRIPTION}}

## Architecture

{{DESCRIBE_THE_ARCHITECTURE_HERE}}

This template provisions:

- **VPC Network** — Dedicated VPC with a primary subnet in `{{REGION}}`
- **GKE Cluster** — {{CLUSTER_TYPE}} cluster (`{{SHORT_NAME}}`) with {{NODE_POOL_DESCRIPTION}}
- **Workload** — {{WORKLOAD_DESCRIPTION}}

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `{{SHORT_NAME}}-<uid>-tf` | `{{SHORT_NAME}}-<uid>-kcc` |
| VPC Network | `{{SHORT_NAME}}-<uid>-tf-vpc` | `{{SHORT_NAME}}-<uid>-kcc-vpc` |
| Subnet | `{{SHORT_NAME}}-<uid>-tf-subnet` | `{{SHORT_NAME}}-<uid>-kcc-subnet` |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| {{NODE_POOL_TYPE}} Node Pool ({{NODE_COUNT}}x {{MACHINE_TYPE}}) | ~${{NODE_COST}} |
| **Total** | **~${{TOTAL_COST}}** |

*Estimates based on sustained use in us-central1. GPU templates incur additional on-demand charges.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/{{TEMPLATE_DIR}}/terraform-helm

# Initialize with GCS backend (or use local state for testing)
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="prefix={{TEMPLATE_DIR}}/terraform-helm"

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
cd templates/{{TEMPLATE_DIR}}/config-connector

# Apply the GCP infrastructure manifests
kubectl apply -n forge-management -f .

# Wait for all resources to be Ready (GKE cluster takes ~10 minutes)
kubectl wait -n forge-management --for=condition=Ready --all \
  --timeout=3600s -f .

# Get cluster credentials (once ContainerCluster is Ready)
CLUSTER_NAME=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template={{SHORT_NAME}}" \
  -o jsonpath='{.items[0].metadata.name}')
LOCATION=$(kubectl get containerclusters.container.cnrm.cloud.google.com \
  -n forge-management -l "template={{SHORT_NAME}}" \
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

{{KCC_LIMITATIONS_SECTION}}
<!--
If any KCC limitations apply, replace the line above with:

### KCC Limitations

- **{{FEATURE_NAME}}**: Not supported in KCC v1beta1 ContainerNodePool. The Terraform path
  uses `{{TF_FIELD}}` for this capability. Tracked upstream:
  https://github.com/GoogleCloudPlatform/k8s-config-connector/issues/TBD
-->

---

## Verification

After deploying with either path, run the validation script to confirm end-to-end functionality:

```bash
export PROJECT_ID="YOUR_PROJECT_ID"
export CLUSTER_NAME="<cluster-name-from-outputs>"
export REGION="us-central1"
chmod +x templates/{{TEMPLATE_DIR}}/validate.sh
./templates/{{TEMPLATE_DIR}}/validate.sh
```

Expected output:
```
Test 1: Cluster Connectivity... Connectivity passed.
Test 2: Node Readiness... All nodes are Ready.
Test 3: Workload Readiness... Workload is available.
All Validation Tests passed successfully for {{TEMPLATE_NAME}}!
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `{{SHORT_NAME}}-tf` |
| `network_name` | VPC network name | `{{SHORT_NAME}}-tf-vpc` |
| `subnet_name` | Subnet name | `{{SHORT_NAME}}-tf-subnet` |

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
