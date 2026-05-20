# Production GKE Cluster for KubeRay

> A production-ready GKE Standard cluster optimized for KubeRay and distributed machine learning workloads.

## Architecture

This template provisions a highly robust and scalable GKE Standard cluster engineered specifically to run [KubeRay](https://github.com/ray-project/kuberay) for distributed machine learning and AI workloads.

This template provisions:

- **GKE Cluster** — GKE Standard cluster (`kuberay-cluster`) in `us-central1` with removal of the default node pool to ensure proper custom node allocation.
- **Node Pool** — A dedicated custom node pool (`kuberay-node-pool`) consisting of `e2-standard-4` machines with GKE Metadata Server enabled to support secure Google Cloud Service Account integrations (Workload Identity).

### Resource Naming

| Resource | Terraform | Config Connector |
|---|---|---|
| GKE Cluster | `kuberay-cluster` | N/A |
| Node Pool | `kuberay-node-pool` | N/A |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| e2-standard-4 Node Pool (2x e2-standard-4) | ~$190 |
| **Total** | **~$265** |

*Estimates based on sustained use in us-central1. Actual costs will vary depending on resource usage, autoscaling, and machine types chosen.*

---

## Deployment Paths

This template supports the Terraform deployment path. Config Connector is currently not implemented or supported for this template.

### Path 1: Terraform

**Prerequisites:** `terraform` ≥ 1.5, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/kuberay-cluster/terraform

# Initialize the Terraform workspace
terraform init

# Review the execution plan
terraform plan 
  -var="project_id=YOUR_PROJECT_ID" 
  -var="region=us-central1"

# Apply the changes to provision the GKE cluster
terraform apply 
  -var="project_id=YOUR_PROJECT_ID" 
  -var="region=us-central1"

# Retrieve cluster credentials
CLUSTER_NAME=$(terraform output -raw cluster_name)
gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "us-central1"

# Verify connectivity and cluster nodes
kubectl get nodes
kubectl get pods -A
```

**Cleanup:**
```bash
terraform destroy -var="project_id=YOUR_PROJECT_ID" -var="region=us-central1"
```

---

### Path 2: Config Connector (KCC)

### KCC Limitations

- **Not Supported**: This template has been configured with `kccSupported: false` and is marked as unsupported. The advanced custom cluster resources and node pool configurations tailored for ML workloads are better managed via the Terraform path.

---

## Verification

After deploying with the Terraform path, run the validation script to confirm basic cluster validation:

```bash
chmod +x templates/kuberay-cluster/validate.sh
./templates/kuberay-cluster/validate.sh
```

Expected output:
```
Running Terraform Lint...
All checks passed!
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `zone` | GCP zone | `us-central1-a` |

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Validation Record

|  | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | pending | skipped |
| **Date** | n/a | n/a |
| **Duration** | n/a | n/a |
| **Region** | us-central1 | n/a |
| **Zones** | - | n/a |
| **Cluster** | -- | n/a |
| **Agent tokens** | - | n/a |
| **Estimated cost** | - | -- |
| **Commit** | n/a | n/a |
