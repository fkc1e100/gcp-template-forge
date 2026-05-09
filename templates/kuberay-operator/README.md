# KubeRay Operator on GKE

> KubeRay Operator on GKE for running Ray clusters.

## Architecture

This template provisions:
- **VPC + Subnet** — VPC with secondary CIDR ranges for pods and services.
- **GKE Standard** — A cluster for running the operator.
- **KubeRay Operator** — Manages the lifecycle of Ray clusters on Kubernetes.

## Deployment Paths

### Path 1: Terraform + Helm

```bash
cd templates/kuberay-operator/terraform-helm
terraform init
terraform apply
```

## Verification

```bash
kubectl get pods -n kuberay-operator
```

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |

## Validation Record
| | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | skipped | skipped |
