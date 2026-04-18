# Basic GKE Hello World

A minimal GKE Standard cluster with a Hello World workload, deployable via Terraform + Helm or Config Connector.

## Architecture

- **VPC + Subnet** — isolated VPC with secondary CIDR ranges for pods and services (`gke-basic-vpc`, `gke-basic-subnet`)
- **GKE Standard Cluster** — fully managed control plane (`gke-basic`)
- **Node Pool** — 1-node pool using `e2-standard-2` spot instances for cost efficiency.
- **Hello World workload** — Google's `hello-app` container, 3 replicas, exposed via LoadBalancer on port 80

## Deployment Paths

### Terraform + Helm (`terraform-helm/`)

This path uses Terraform to provision the infrastructure and Helm (invoked via CI or manually) to deploy the workload.

#### Prerequisites
- Terraform installed
- Access to a GCP project with the GKE API enabled
- A GCS bucket for Terraform state

#### Deployment Commands
```bash
cd terraform-helm
terraform init \
  -backend-config="bucket=<TF_STATE_BUCKET>" \
  -backend-config="prefix=templates/basic-gke-hello-world/terraform-helm"
terraform apply -var="project_id=<PROJECT_ID>"
```

#### Verification
Once Terraform completes, get the cluster credentials and verify the Helm deployment:
```bash
gcloud container clusters get-credentials gke-basic-tf --region <REGION> --project <PROJECT_ID>
kubectl get pods
kubectl get service hello-world
```
The workload is automatically deployed by the CI/CD pipeline, but can be manually deployed using the Helm chart in `workload/`.

---

### Config Connector (`config-connector/`)

This path uses Kubernetes Config Connector (KCC) manifests to provision both the infrastructure and the workload.

#### Prerequisites
- A GKE cluster with Config Connector installed and configured.
- The KCC namespace should have the necessary IAM permissions to manage resources in the target project.

#### Deployment Commands
```bash
# Apply all manifests in the directory
kubectl apply -f config-connector/
```

This will create:
- `ComputeNetwork` and `ComputeSubnetwork`
- `ContainerCluster` and `ContainerNodePool`
- `Deployment` and `Service` for the `hello-world` workload.

#### Verification
Wait for the resources to become ready:
```bash
kubectl wait --for=condition=Ready containercluster gke-basic-kcc-v2 --timeout=20m
kubectl get service hello-world
```
Find the external IP of the load balancer and visit it:
```bash
kubectl get service hello-world -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
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

*Estimated from GCP pricing (us-central1, Standard pricing)*

| Resource | Config | Estimated cost |
|---|---|---|
| GKE Management Fee | per cluster | ~$0.10/hr (~$73/mo) |
| E2-standard-2 (Spot) | 1 node | ~$0.02/hr |
| Load Balancer | per rule | ~$0.025/hr |
| **Total** | | **~$0.145/hr (~$105/mo)** |

## Cleanup

```bash
# Terraform path
cd terraform-helm && terraform destroy

# KCC path
kubectl delete -f config-connector/ --wait=true
```

## Validation Record

|  | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | success | success |
| **Date** | 2026-04-18 | 2026-04-18 |
| **Duration** | 9m 39s | 12m 15s |
| **Region** | us-central1 | us-central1 |
| **Commit** | HEAD | HEAD |
