# GKE Custom Compute Node Pool Reference Architecture

> This template provisions a zonal GKE cluster with a dedicated node pool optimized with custom compute shapes (`e2-custom-4-16384` with 4 vCPUs and 16 GB of RAM) and labels. It deploys a standard workload with Helm and Config Connector, verifying scheduling on the custom node pool.

## Architecture

This reference architecture demonstrates how to provision and utilize custom compute machine types on GKE. Custom machine types allow you to fine-tune your CPU and memory configurations to align precisely with workload demands, optimizing costs compared to standard predefined machine types.

This template provisions:

- **VPC Network** — Custom VPC designed specifically for private Google access and secondary IP ranges for GKE.
- **GKE Cluster** — Zonal GKE standard cluster with workload identity enabled.
- **Custom Compute Node Pool** — Dedicated GKE node pool configured with custom instance configurations (`e2-custom-4-16384`) and explicit node locations and labels.
- **Workload** — A standard workload using `nodeSelector` or `nodeAffinity` to target the custom compute node pool.

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `gke-custom-compute-<uid>-tf` | `gke-custom-compute-<uid>-kcc` |
| VPC Network | `gke-custom-compute-<uid>-tf-vpc` | `gke-custom-compute-<uid>-kcc-vpc` |
| Subnet | `gke-custom-compute-<uid>-tf-subnet` | `gke-custom-compute-<uid>-kcc-subnet` |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| Custom Node Pool (2x e2-custom-4-16384) | ~$114 |
| LoadBalancer & Networking | ~$18 |
| **Total** | **~$207** |

*Estimates based on sustained use in us-central1. Actual prices vary on-demand.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/gke-custom-compute-class/terraform-helm

# Initialize
terraform init

# Review the plan
terraform plan -var="project_id=YOUR_PROJECT_ID"

# Apply (provisions GKE cluster and supporting infrastructure)
terraform apply -var="project_id=YOUR_PROJECT_ID"
```

**Cleanup:**
```bash
terraform destroy -var="project_id=YOUR_PROJECT_ID"
```

---

### Path 2: Config Connector (KCC)

**Prerequisites:** A running GKE cluster with Config Connector installed.

```bash
cd templates/gke-custom-compute-class/config-connector

# Apply the GCP infrastructure manifests
kubectl apply -n forge-management -f .
```

---

## Validation

To validate the deployment:

```bash
export PROJECT_ID="YOUR_PROJECT_ID"
export CLUSTER_NAME="<cluster-name>"
export REGION="us-central1"
chmod +x templates/gke-custom-compute-class/validate.sh
./templates/gke-custom-compute-class/validate.sh
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `gke-custom-compute-tf` |
| `network_name` | VPC network name | `gke-custom-compute-tf-vpc` |
| `subnet_name` | Subnet name | `gke-custom-compute-tf-subnet` |
| `service_account` | GKE node pool service account | required |

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Validation Record
| | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | skipped | skipped |
| **Date** | 2026-05-22 | 2026-05-22 |
| **Duration** | n/a | n/a |
| **Region** | us-central1 | us-central1 (KCC cluster) |
| **Zones** | - | forge-management namespace |
| **Cluster** | -- | krmapihost-kcc-instance |
| **Agent tokens** | - | (shared session) |
| **Estimated cost** | - | -- |
| **Commit** | n/a | n/a |
