# Basic GKE Hello World

A minimal GKE Standard cluster with a Hello World workload, deployable via Terraform + Helm or Config Connector.

## Architecture

- **VPC + Subnet** — isolated VPC with secondary CIDR ranges for pods and services (`basic-gke-hello-world-vpc`)
- **GKE Standard** — cost-optimized cluster with a single e2-standard-2 spot node pool
- **Hello World workload** — Google's `hello-app` container, 3 replicas, exposed via LoadBalancer on port 80

## Deployment Paths

### Terraform + Helm (`terraform-helm/`)

1. **Provision Infrastructure**:
   ```bash
   cd terraform-helm
   terraform init \
     -backend-config="bucket=<TF_STATE_BUCKET>" \
     -backend-config="prefix=templates/basic-gke-hello-world/terraform-helm"
   terraform apply -var="project_id=<PROJECT_ID>" -var="service_account=<SA_EMAIL>"
   ```

2. **Deploy Workload**:
   After Terraform completes, get credentials and deploy the Helm chart:
   ```bash
   gcloud container clusters get-credentials basic-gke-hello-world --region us-central1 --project <PROJECT_ID>
   helm upgrade --install hello-world ./workload/ --values ./workload/values.yaml --namespace default --wait
   ```

Provisions VPC + subnet + GKE Standard, then deploys the `hello-world` Helm chart into the target cluster.

### Config Connector (`config-connector/`)

1. **Provision Infrastructure**:
   Apply the core infrastructure manifests to your Config Connector management namespace:
   ```bash
   kubectl apply -n <KCC_NAMESPACE> -f config-connector/
   ```
   Provisions `ComputeNetwork`, `ComputeSubnetwork`, `ContainerCluster` (Standard mode), and `ContainerNodePool` as KCC-managed resources.

2. **Wait for Infrastructure**:
   Monitor the status of the cluster and node pool until they are `Ready`:
   ```bash
   kubectl wait --for=condition=Ready containercluster basic-gke-hello-world -n <KCC_NAMESPACE> --timeout=30m
   ```

3. **Deploy Workload**:
   Once the cluster is ready, get credentials and apply the workload manifests directly to the **workload cluster**:
   ```bash
   gcloud container clusters get-credentials basic-gke-hello-world --region us-central1 --project <PROJECT_ID>
   kubectl apply -f config-connector-workload/workload.yaml
   ```

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
| VPC | TF | `basic-gke-hello-world-vpc` |
| VPC | KCC | `basic-gke-hello-world-vpc` |
| Subnet | TF | `basic-gke-hello-world-subnet` |
| Subnet | KCC | `basic-gke-hello-world-subnet` |
| GKE cluster | TF | `basic-gke-hello-world` |
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
# Delete workload from workload cluster
kubectl delete -f config-connector-workload/workload.yaml

# Delete infrastructure from management cluster
kubectl delete -n <KCC_NAMESPACE> -f config-connector/ --wait=true
```

## Validation Record

|  | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | success | success |
| **Date** | 2026-04-19 | 2026-04-19 |
| **Duration** | 9m 39s | 10m 15s |
| **Region** | us-central1 | us-central1 (KCC cluster) |
| **Zones** | us-central1-a,us-central1-b,us-central1-c,us-central1-f | forge-management namespace |
| **Cluster** | basic-gke-hello-world | basic-gke-hello-world |
| **Agent tokens** | not recorded | (shared session) |
| **Estimated cost** | - | -- |
| **Commit** | 5bcfe65 | |


