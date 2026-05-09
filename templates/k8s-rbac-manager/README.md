# K8s RBAC Manager

> Kubernetes RBAC management using Config Connector and Terraform.

## Architecture

This template provides a skeleton for managing Kubernetes Role-Based Access Control (RBAC) resources. It demonstrates how to use Config Connector to manage K8s-level access as Google Cloud resources, allowing for unified infrastructure-as-code management of both cloud resources and cluster permissions.

This template provisions:

- **Placeholder Infrastructure** — A foundation for RBAC management.
- **Config Connector Resources** — Custom resources for RBAC configuration.

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `k8s-rbac-mgr-tf` | `k8s-rbac-mgr-kcc` |

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/k8s-rbac-manager/terraform-helm

# Initialize
terraform init

# Review and Apply
terraform plan -var="project_id=YOUR_PROJECT_ID"
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

After deploying with either path, run the validation script to confirm end-to-end functionality:

```bash
export PROJECT_ID="YOUR_PROJECT_ID"
export REGION="us-central1"
chmod +x templates/k8s-rbac-manager/validate.sh
./templates/k8s-rbac-manager/validate.sh
```

Expected output:
```
Test 1: Cluster Connectivity... Connectivity passed.
Test 2: RBAC Config existence... Config exists.
All Validation Tests passed successfully for k8s-rbac-manager!
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
