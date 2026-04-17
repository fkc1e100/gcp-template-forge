# Basic GKE Hello World

A minimal GKE Autopilot cluster with a Hello World workload, deployable via Terraform + Helm or Config Connector.

## Architecture

- **VPC + Subnet** — isolated VPC with secondary CIDR ranges for pods and services (`gke-basic-vpc`, `gke-basic-subnet`)
- **GKE Autopilot** — fully managed cluster (`gke-basic`); no node pool configuration required
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

Creates `ComputeNetwork`, `ComputeSubnetwork`, and `ContainerCluster` (Autopilot mode) as KCC resources managed by the Config Connector operator. Workload is deployed and verified via the `validate.sh` script.

## Resource Naming

| Resource | Path | Name |
|---|---|---|
| VPC | TF | `gke-basic-tf-vpc` |
| VPC | KCC | `gke-basic-kcc-vpc` |
| Subnet | TF | `gke-basic-tf-subnet` |
| Subnet | KCC | `gke-basic-kcc-subnet` |
| GKE cluster | TF | `gke-basic-tf` |
| GKE cluster | KCC | `gke-basic-kcc` |

## Performance & Cost Estimates

*Estimated from GCP pricing (us-central1, Autopilot pricing)*

| Resource | Config | Estimated cost |
|---|---|---|
| Autopilot cluster (idle) | 0 user pods scheduled | ~$0.10/hr cluster fee (~$73/mo) |
| Autopilot workload (hello-world) | 0.25 vCPU + 128 Mi per pod | ~$0.01/hr per pod |
| Cloud NAT | per-gateway fee + data processing | ~$0.004/hr (~$3/mo) |
| **Total (1 pod running)** | | **~$0.11/hr (~$80/mo)** |

Autopilot billing is per-pod resource request, not per node — there is no idle node cost. The cluster management fee (~$0.10/hr) applies whenever the cluster exists regardless of workload scale. Scale to zero pods to stop workload billing.

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
| **Status** | success | pending |
| **Date** | 2026-04-11 | |
| **Duration** | 9m 39s | |
| **Region** | us-central1 | us-central1 (KCC cluster) |
| **Zones** | us-central1-a,us-central1-b,us-central1-c,us-central1-f | forge-management namespace |
| **Cluster** | gke-basic-tf | gke-basic-kcc |
| **Agent tokens** | not recorded | (shared session) |
| **Estimated cost** | - | -- |
| **Commit** | 2c375256 | |


