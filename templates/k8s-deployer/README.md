# K8s Deployer

> A template to deploy a Kubernetes workload via KCC (Kubernetes Config Connector).

## Architecture

This template provisions a basic GKE infrastructure and an Nginx workload. It demonstrates the dual-path deployment model, allowing you to manage resources via Terraform+Helm or entirely via Config Connector.

This template provisions:

- **VPC Network** — Dedicated VPC with a primary subnet.
- **GKE Cluster** — A standard GKE cluster for running workloads.
- **Workload** — An Nginx deployment exposed via a Kubernetes Service.

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `k8s-deployer-tf` | `k8s-deployer-kcc` |
| VPC Network | `k8s-deployer-tf-vpc` | `k8s-deployer-kcc-vpc` |

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/k8s-deployer/terraform-helm

# Initialize
terraform init

# Apply
terraform apply -var="project_id=YOUR_PROJECT_ID"
```

---

### Path 2: Config Connector (KCC)

**Prerequisites:** A running GKE cluster with Config Connector installed.

```bash
cd templates/k8s-deployer/config-connector

# Apply the manifests
kubectl apply -f .

# Deploy the workload
kubectl apply -f ../config-connector-workload/
```

---

## Verification

After deploying with either path, run the validation script to confirm end-to-end functionality:

```bash
export PROJECT_ID="YOUR_PROJECT_ID"
chmod +x templates/k8s-deployer/validate.sh
./templates/k8s-deployer/validate.sh
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
