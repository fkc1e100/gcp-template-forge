# KubeRay Operator on GKE

> Deploys the KubeRay Operator on GKE for managing Ray clusters.

## Architecture

This template deploys the KubeRay Operator onto a Google Kubernetes Engine (GKE) cluster. The operator manages the lifecycle of Ray clusters on Kubernetes, providing custom resources for RayClusters.

This template provisions:

- **VPC Network** — Dedicated VPC with a primary subnet.
- **GKE Cluster** — Standard cluster with an e2-medium node pool.
- **KubeRay Operator** — Deployed into the `kubeflow` namespace.

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `kuberay-operator-<uid>-tf` | `kuberay-operator-<uid>-kcc` |
| VPC Network | `kuberay-operator-<uid>-tf-vpc` | `kuberay-operator-<uid>-kcc-vpc` |

---

## Deployment Paths

### Path 1: Terraform

**Prerequisites:** `terraform`, `kubectl`, `gcloud`.

```bash
cd templates/kuberay-operator/terraform-helm
terraform init
terraform apply -var="project_id=YOUR_PROJECT_ID"
```

### Path 2: Kubernetes Manifests

**Prerequisites:** A running GKE cluster.

```bash
cd templates/kuberay-operator/config-connector-workload
kubectl apply -f .
```

---

## Verification

Run the validation script:
```bash
./templates/kuberay-operator/validate.sh
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |

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
