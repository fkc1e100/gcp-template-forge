# Basic GKE Hello World

A minimal GKE Standard cluster with a Hello World workload, deployable via Terraform + Helm or Config Connector.

## Architecture

- **VPC + Subnet** — isolated VPC with secondary CIDR ranges for pods and services (`gke-basic-tf-vpc` or `gke-basic-kcc-v2-vpc`)
- **GKE Standard** — cost-optimized cluster with a single e2-standard-2 spot node pool
- **Hello World workload** — Google's `hello-app` container, 3 replicas, exposed via LoadBalancer on port 80

## Deployment Paths

### Terraform + Helm (`terraform-helm/`)

```bash
cd terraform-helm
terraform init \
  -backend-config="bucket=<TF_STATE_BUCKET>" \
  -backend-config="prefix=templates/basic-gke-hello-world/terraform-helm"
terraform apply -var="project_id=<PROJECT_ID>"
```

Provisions VPC + subnet + GKE Standard, then deploys the `hello-world` Helm chart into the target cluster.

### Config Connector (`config-connector/`)

```bash
kubectl apply -n <KCC_NAMESPACE> -f config-connector/
```

Provisions `ComputeNetwork`, `ComputeSubnetwork`, `ContainerCluster` (Standard mode), and `ContainerNodePool` as KCC resources. 

> **Note**: Workload deployment via KCC is pending (tracked in Issue 1.1). Currently, KCC provisions the underlying infrastructure; once Issue 1.1 is resolved, KCC will also manage the Kubernetes `Deployment` and `Service` for the hello-world workload.

### Verification

To verify the deployment:

1. **Check Infrastructure Readiness**:
   Monitor the KCC resources in the management cluster until all report `READY=True`:
   ```bash
   kubectl get gcp -n <KCC_NAMESPACE>
   ```

2. **Run Validation Script**:
   Use the `validate.sh` script to verify cluster connectivity and workload health (requires `gcloud` and `kubectl`):
   ```bash
   export PROJECT_ID=<PROJECT_ID>
   export CLUSTER_NAME=gke-basic-kcc-v2
   export REGION=us-central1
   ./validate.sh
   ```

## Resource Naming

| Resource | Path | Name |
|---|---|---|
| VPC | TF | `gke-basic-tf-vpc` |
| VPC | KCC | `gke-basic-kcc-v2-vpc` |
| Subnet | TF | `gke-basic-tf-subnet` |
| Subnet | KCC | `gke-basic-kcc-v2-subnet` |
| GKE cluster | TF | `gke-basic-tf` |
| GKE cluster | KCC | `gke-basic-kcc-v2` |

## Performance & Cost Estimates

*Estimated from GCP pricing (us-central1, Standard Spot pricing)*

| Resource | Config | Estimated cost |
|---|---|---|
| GKE Cluster fee | Standard Management Fee | ~$0.10/hr (~$73/mo) |
| Node (e2-standard-2) | 1x Spot Instance | ~$0.02/hr (~$15/mo) |
| LoadBalancer | Forwarding Rule + processing | ~$0.025/hr (~$18/mo) |
| **Total (1 node cluster)** | | **~$0.145/hr (~$106/mo)** |

GKE Standard management fee applies per cluster. Using Spot instances for the node pool significantly reduces compute costs for sandbox/testing environments.

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
| **Cluster** | gke-basic-tf | gke-basic-kcc-v2 |
| **Agent tokens** | not recorded | (shared session) |
| **Estimated cost** | - | -- |
| **Commit** | 2c375256 | |


