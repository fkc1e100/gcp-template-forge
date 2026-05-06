# Basic GKE Hello World

A minimal GKE Standard cluster with a Hello World workload, deployable via Terraform + Helm or Config Connector.

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Architecture

- **VPC + Subnet** — isolated VPC with secondary CIDR ranges for pods and services (`gke-basic-tf-vpc` or `basic-gke-hello-world-vpc`)
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

1. **Deploy Infrastructure**:
   ```bash
   kubectl apply -n <KCC_NAMESPACE> -f config-connector/
   ```

2. **Deploy Workload**:
   Once the cluster is ready, get credentials for the target cluster and apply the workload:
   ```bash
   gcloud container clusters get-credentials basic-gke-hello-world --region us-central1 --project <PROJECT_ID>
   kubectl apply -f config-connector-workload/workload.yaml
   ```

Provisions `ComputeNetwork`, `ComputeSubnetwork`, `ContainerCluster` (Standard mode), and `ContainerNodePool` as KCC resources, then deploys the `hello-world` workload directly to the target cluster.

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
   export CLUSTER_NAME=basic-gke-hello-world
   export REGION=us-central1
   ./validate.sh
   ```

## Resource Naming

| Resource | Path | Name |
|---|---|---|
| VPC | TF | `gke-basic-tf-vpc` |
| VPC | KCC | `basic-gke-hello-world-vpc` |
| Subnet | TF | `gke-basic-tf-subnet` |
| Subnet | KCC | `basic-gke-hello-world-subnet` |
| GKE cluster | TF | `gke-basic-tf` |
| GKE cluster | KCC | `basic-gke-hello-world` |

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

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `gke-basic-tf` |
| `network_name` | VPC network name | `gke-basic-tf-vpc` |
| `subnet_name` | Subnet name | `gke-basic-tf-subnet` |
| `service_account` | Node pool service account | required |

## Validation Record

|  | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | success | pending |
| **Date** | 2026-04-20 | 2026-04-20 |
| **Duration** | 10m 15s | 15m 20s |
| **Region** | us-central1 | us-central1 (regional) |
| **Zones** | us-central1-a,us-central1-b,us-central1-c,us-central1-f | us-central1 (regional) |
| **Cluster** | gke-basic-tf | basic-gke-hello-world |
| **Agent tokens** | not recorded | (shared session) |
| **Estimated cost** | - | -- |
| **Commit** | multiple | pending |


