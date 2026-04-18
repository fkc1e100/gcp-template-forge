# Enterprise GKE Template

A production-ready GKE Standard cluster with security hardening, observability, and cost-optimized node pools.

## Architecture

- **Hardened VPC** — Private VPC with Cloud NAT for egress, no public IPs on nodes.
- **GKE Standard Cluster** — Regional cluster with control plane authorized networks and Shielded GKE Nodes.
- **Node Pools** — Optimized node pools with taints/tolerations and spot instances for non-critical workloads.
- **Security** — Workload Identity, Network Policies, Pod Security Admission (Baseline/Restricted).
- **Workload** — Unprivileged Nginx deployment with HPA, PDB, and resource limits.

## Deployment Paths

### Terraform + Helm (`terraform-helm/`)

This path uses Terraform for infra and Helm for the hardened workload.

#### Prerequisites
- Terraform installed
- GCS bucket for state
- IAM permissions: `roles/container.admin`, `roles/compute.networkAdmin`, `roles/iam.serviceAccountAdmin`

#### Deployment Commands
```bash
cd terraform-helm
terraform init -backend-config="bucket=<TF_STATE_BUCKET>" -backend-config="prefix=templates/enterprise-gke/terraform-helm"
terraform apply -var="project_id=<PROJECT_ID>"
```

#### Verification
```bash
gcloud container clusters get-credentials gke-ent-tf --region us-central1
kubectl get pods
kubectl get networkpolicy
```

---

### Config Connector (`config-connector/`)

This path uses KCC to manage the entire lifecycle of the enterprise stack.

#### Prerequisites
- GKE cluster with Config Connector installed.
- KCC configured to manage the target project.

#### Deployment Commands
```bash
# Apply infra and workload manifests
kubectl apply -f config-connector/
```

#### Verification
Wait for KCC resources to sync:
```bash
kubectl wait --for=condition=Ready containercluster gke-ent-kcc --timeout=20m
kubectl get deployment enterprise-gke-workload
kubectl describe networkpolicy enterprise-gke-netpol
```

## Resource Naming

| Resource | Path | Name |
|---|---|---|
| VPC | TF | `gke-ent-tf-vpc` |
| VPC | KCC | `gke-ent-kcc-vpc` |
| GKE Cluster | TF | `gke-ent-tf` |
| GKE Cluster | KCC | `gke-ent-kcc` |

## Performance & Cost Estimates

| Resource | Config | Estimated Cost |
|---|---|---|
| Regional GKE Cluster | 3 zones | ~$0.10/hr |
| E2-standard-4 Nodes | 3 nodes (Spot) | ~$0.12/hr |
| Cloud NAT | 1 gateway | ~$0.004/hr + traffic |
| **Total** | | **~$0.224/hr (~$160/mo)** |

## Cleanup
```bash
# Terraform
terraform destroy

# KCC
kubectl delete -f config-connector/
```
