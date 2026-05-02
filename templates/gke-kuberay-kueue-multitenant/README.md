# Multi-Tenant Ray on GKE with Equitable Queuing

A GKE template demonstrating how to solve the "Noisy Neighbor" problem for shared GPU clusters using the KubeRay Operator and the Kueue Operator. 

## Architecture

- **VPC + Subnet** — VPC with secondary CIDR ranges for pods and services.
- **GKE Standard** — A cluster featuring an autoscaled GPU node pool (using L4 GPUs via `g2-standard-4` spot instances) and a standard system node pool.
- **KubeRay Operator** — Manages the lifecycle of Ray clusters on Kubernetes.
- **Kueue Operator** — Cloud-native job queueing and equitable resource sharing.
- **Workloads** — Two namespaces (`team-a` and `team-b`), each with a Kueue `LocalQueue` linked to a `ClusterQueue` sharing a single GPU `Cohort`. Kueue ensures that if Team A requests excess GPUs, their pods remain in a pending state until Team B finishes their work.

## Deployment Paths

### Terraform + Helm (`terraform-helm/`)

```bash
cd terraform-helm
terraform init
terraform apply -var="project_id=my-project-id" -var="service_account=my-service-account@my-project-id.iam.gserviceaccount.com"
```

### Config Connector (`config-connector/`)
(Not implemented yet for this template)

## Verification

After deploying, verify the Kueue setup:
```bash
kubectl get clusterqueues
kubectl get localqueues -A
kubectl get rayclusters -A
```
