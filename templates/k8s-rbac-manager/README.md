# K8s RBAC Manager

> Kubernetes RBAC management using Config Connector and Terraform.

## Architecture

This template provides a framework for managing Kubernetes Role-Based Access Control (RBAC) using infrastructure-as-code. It demonstrates how to define RBAC roles, role bindings, and service accounts.

This template provisions:

- **VPC Network** — Dedicated VPC for the RBAC management cluster
- **GKE Cluster** — Standard cluster (`k8s-rbac-mgr`)
- **Workload** — RBAC custom resources and policies

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `k8s-rbac-mgr-<uid>-tf` | `k8s-rbac-mgr-<uid>-kcc` |
| VPC Network | `k8s-rbac-mgr-<uid>-tf-vpc` | `k8s-rbac-mgr-<uid>-kcc-vpc` |
| Subnet | `k8s-rbac-mgr-<uid>-tf-subnet` | `k8s-rbac-mgr-<uid>-kcc-subnet` |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| Node Pool (1x e2-standard-2) | ~$50 |
| **Total** | **~$125** |

*Estimates based on sustained use in us-central1.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/k8s-rbac-manager/terraform-helm

# Initialize
terraform init

# Apply
terraform apply -var="project_id=YOUR_PROJECT_ID"
```

---

### Path 2: Config Connector (KCC)

**Prerequisites:** A running GKE cluster with Config Connector installed.

```bash
cd templates/k8s-rbac-manager/config-connector

# Apply the manifests
kubectl apply -f .
```

---

## Verification

Run the validation script:

```bash
./templates/k8s-rbac-manager/validate.sh
```

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Validation Record

| | Terraform + Helm | Config Connector |
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
