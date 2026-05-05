# Enterprise GKE Cluster

> Enterprise-grade GKE with Binary Authorization, Workload Identity, and hardened security controls

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Architecture

This template provides an enterprise-grade Google Kubernetes Engine (GKE) architecture. It demonstrates two deployment paths: Terraform + Helm for traditional infrastructure-as-code and Config Connector (KCC) for a Kubernetes-native approach to managing GCP resources.

> **Warning: Binary Authorization**
> This template enables Binary Authorization in `PROJECT_SINGLETON_POLICY_ENFORCE` mode. Ensure your GCP project has a Binary Authorization policy configured, otherwise pod deployments may be blocked.

This template provisions:

- **VPC Network** — Private VPC with dedicated secondary ranges for pods and services.
- **GKE Cluster** — GKE Standard cluster (`enterprise-gke`) with security hardening (Binary Authorization, Security Posture).
- **Node Pool** — E2-standard-4 instances (Spot) with Secure Boot and Integrity Monitoring.
- **Cloud NAT** — Enables egress for private nodes without public IP addresses.
- **Workload** — Nginx-based production-ready workload with Workload Identity.

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
| E2-standard-4 Node Pool (1x node, Spot) | ~$29 |
| Load Balancer (1x external) | ~$18 |
| Cloud NAT | ~$3 |
| **Total** | **~$125** |

*Estimates based on sustained use in us-central1 with spot pricing for nodes. On-demand nodes increase total cost to ~$200/mo.*

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

**Note:** `create_service_accounts` defaults to `false` for CI compatibility. Set to `true` for standalone deployments to create dedicated, least-privileged service accounts for nodes and workloads.

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

- **Network Policy Provider**: KCC ContainerCluster does not support the `network_policy.provider = "CALICO"` field. This template uses `spec.datapathProvider: ADVANCED_DATAPATH` in KCC to enable equivalent GKE Dataplane V2 network policy enforcement.

---

## Verification

After deploying with either path, run the validation script to confirm end-to-end functionality:

```bash
export PROJECT_ID="YOUR_PROJECT_ID"
export CLUSTER_NAME="enterprise-gke-tf" # or enterprise-gke-kcc
export REGION="us-central1"
chmod +x templates/enterprise-gke/validate.sh
./templates/enterprise-gke/validate.sh
```

Expected output:
```
Test 1: Cluster Connectivity... Connectivity passed.
Test 2: Node Readiness... All nodes are Ready.
Test 3: Workload Readiness... Workload is available.
All Validation Tests passed successfully for enterprise-gke!
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
| `create_service_accounts` | Whether to create dedicated IAM SAs | `false` |

---

## Validation Record

|  | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | success | success |
| **Date** | 2026-04-22 | 2026-04-22 |
| **Duration** | 21m 59s | 21m 57s |
| **Region** | us-central1 | us-central1 (KCC cluster) |
| **Zones** | us-central1-a,us-central1-b,us-central1-c,us-central1-f | us-central1 (regional) |
| **Cluster** | enterprise-gke-tf | enterprise-gke-kcc |
| **Agent tokens** | 495,000 in / 70,000 out (multi-session) | (shared session) |
| **Estimated cost** | $0.55 | -- |
| **Commit** | dde1b73 | dde1b73 |
