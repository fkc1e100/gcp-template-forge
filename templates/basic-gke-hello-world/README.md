# Basic GKE Hello World

A minimal GKE Autopilot cluster with a Hello World workload, deployable via Terraform + Helm or Config Connector.

## Architecture

- **VPC + Subnet** — isolated VPC with secondary CIDR ranges for pods and services (`basic-gke-vpc`, `basic-gke-subnet`)
- **GKE Autopilot** — fully managed cluster (`basic-gke`); no node pool configuration required
- **Hello World workload** — Google's `hello-app` container, 3 replicas, exposed via LoadBalancer on port 80

## Deployment Paths

### Terraform + Helm (`terraform-helm/`)

```bash
cd terraform-helm
terraform init \
  -backend-config="bucket=<TF_STATE_BUCKET>" \
  -backend-config="prefix=templates/1-basic-gke-hello-world/terraform-helm"
terraform apply -var="project_id=<PROJECT_ID>"
```

Provisions VPC + subnet + GKE Autopilot, then deploys the `hello-world` Helm chart into the `hello-world` namespace.

### Config Connector (`config-connector/`)

```bash
kubectl apply -n <KCC_NAMESPACE> -f config-connector/
```

Creates `ComputeNetwork`, `ComputeSubnetwork`, and `ContainerCluster` (Autopilot mode) as KCC resources managed by the Config Connector operator.

## Resource Naming

| Resource | Name |
|---|---|
| VPC | `basic-gke-vpc` |
| Subnet | `basic-gke-subnet` |
| GKE cluster | `basic-gke` |

## Cleanup

```bash
# Terraform path
cd terraform-helm && terraform destroy

# KCC path
kubectl delete -n <KCC_NAMESPACE> -f config-connector/ --wait=true
```

## Validation Record

|  | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | skipped | success |
| **Date** | 2026-04-11 | 2026-04-11 |
| **Duration** | n/a | 8m 2s |
| **Region** | us-central1 | us-central1 (KCC cluster) |
| **Zones** | us-central1 | forge-management namespace |
| **Cluster** | -- | krmapihost-kcc-instance |
| **Agent tokens** | not recorded | (shared session) |
| **Estimated cost** | - | -- |
| **Commit** | 7b48e3a8 | 7b48e3a8 |

