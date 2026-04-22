# Template: Enterprise GKE Cluster and Workload

## Overview
This template provides an enterprise-grade Google Kubernetes Engine (GKE) architecture. It demonstrates two deployment paths: Terraform + Helm for traditional infrastructure-as-code and Config Connector (KCC) for a Kubernetes-native approach to managing GCP resources.

## Architecture
- **VPC Network** — Private VPC with dedicated secondary ranges for pods and services.
- **GKE Standard Cluster** — VPC-native, private cluster with security hardening (Binary Authorization, Security Posture).
- **Node Pool** — E2-standard-4 instances (Spot) with Secure Boot and Integrity Monitoring.
- **Cloud NAT** — Enables egress for private nodes without public IP addresses.
- **Master Authorized Networks** — Restricts access to the GKE control plane to specified IP ranges.
- **Workload Identity** — Seamless IAM integration for Kubernetes workloads.

## Deployment Paths

### Terraform + Helm (`terraform-helm/`)
- Provisions a dedicated VPC with specific secondary CIDRs for pods and services.
- Deploys a private, VPC-native GKE Standard cluster with Workload Identity and Security Posture monitoring.
- Deploys the application workload using a production-ready Helm chart.

### Config Connector (`config-connector/`)
- Uses KCC resources (`ContainerCluster`, `ContainerNodePool`, `ComputeNetwork`, `ComputeSubnetwork`) to provision the same infrastructure.
- Manages IAM roles and Service Accounts via KCC for seamless Workload Identity integration.
- Deploys the workload using Kubernetes-native manifests (Deployment, Service, HPA, etc.) located in the `config-connector-workload/` directory.

## Deployment Instructions

### Terraform + Helm

```bash
cd terraform-helm
terraform init \
  -backend-config="bucket=<TF_STATE_BUCKET>" \
  -backend-config="prefix=templates/enterprise-gke/terraform-helm"
terraform apply -var="project_id=<PROJECT_ID>" -var="service_account=<NODE_SA_EMAIL>" -var="create_service_accounts=true"

# 2. Deploy the application workload using Helm
gcloud container clusters get-credentials enterprise-gke-tf --region us-central1
helm upgrade --install release ./workload --namespace gke-workload --create-namespace
```

*Note: `create_service_accounts` defaults to `false` to ensure compatibility with restricted environments like CI. For production deployments, set it to `true` to create dedicated, least-privileged service accounts for nodes and workloads.*

### Config Connector

```bash
# 1. Apply the infrastructure manifests to the KCC management cluster
kubectl apply -n <KCC_NAMESPACE> -f config-connector/

# 2. Once the cluster is READY, apply the workload manifests to the target cluster
# Get credentials for the new cluster first
gcloud container clusters get-credentials enterprise-gke-kcc --region us-central1
kubectl apply -f config-connector-workload/
```

## Verification

To verify the deployment:

1. **Check Infrastructure Readiness** (KCC path):
   Monitor the KCC resources in the management cluster until all report `READY=True`:
   ```bash
   kubectl get gcp -n <KCC_NAMESPACE>
   ```

2. **Run Validation Script**:
   Use the `validate.sh` script to verify cluster connectivity and workload health:
   ```bash
   export PROJECT_ID=<PROJECT_ID>
   export CLUSTER_NAME=enterprise-gke-tf # or enterprise-gke-kcc for KCC path
   export REGION=us-central1
   ./validate.sh
   ```

## Cluster Details
- **Type**: GKE Standard
- **Release channel**: REGULAR
- **Node pools**: enterprise-gke-pool (e2-standard-4, spot nodes)
- **Networking**: VPC-native, Private nodes, dedicated VPC per issue

## Workload Details
- **Application**: Nginx-based production-ready workload
- **Access**: LoadBalancer
- **Dependencies**: IAM Workload Identity

## Enabled Features
- [x] Workload Identity
- [x] VPC-native networking
- [x] Private cluster + Cloud NAT
- [x] Master Authorized Networks
- [x] Binary Authorization
- [x] Network Policy (Calico)
- [x] Security Posture Monitoring
- [x] Vertical / Horizontal Pod Autoscaler
- [x] Config Connector resources: ContainerCluster, ContainerNodePool, ComputeNetwork, ComputeSubnetwork, IAMServiceAccount, IAMPolicyMember, ComputeRouter, ComputeRouterNAT, Deployment, Service
- [ ] Confidential GKE Nodes
- [ ] Cluster Autoscaler / Node Auto-provisioning
- [ ] DWS + Kueue (accelerator templates)
- [ ] GPU node pool with driver auto-install

## Performance & Cost Estimates

*Estimated from GCP pricing (us-central1, spot pricing where applicable)*

| Resource | Config | Estimated cost |
|---|---|---|
| Node pool | e2-standard-4 × 1 node, spot | ~$0.04/hr (~$29/mo) |
| Boot disk | 50 GB pd-standard per node | ~$0.004/hr (~$3/mo) |
| Load balancer | 1× regional external LB | ~$0.025/hr (~$18/mo) |
| Cloud NAT | per-gateway fee + data processing | ~$0.004/hr (~$3/mo) |
| **Total (idle cluster, spot)** | | **~$0.07/hr (~$53/mo)** |
| **Total (on-demand nodes)** | e2-standard-4 on-demand | ~$0.14/hr (~$100/mo) |

Spot node interruptions are expected during validation; the workload is stateless (Nginx) so restarts are safe. Use on-demand nodes for production.

## Cleanup

### Terraform Path
```bash
cd terraform-helm && terraform destroy
```

### KCC Path
```bash
kubectl delete -n <KCC_NAMESPACE> -f config-connector/ --wait=true
```

## Validation Record

|  | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | success | success |
| **Date** | 2026-04-21 | 2026-04-21 |
| **Duration** | 16m 37s | 15m 15s |
| **Region** | us-central1 | us-central1 (KCC cluster) |
| **Zones** | us-central1-a,us-central1-b,us-central1-c,us-central1-f | us-central1 (regional) |
| **Cluster** | enterprise-gke-tf | enterprise-gke-kcc |
| **Agent tokens** | 480,000 in / 65,000 out (multi-session) | (shared session) |
| **Estimated cost** | $0.48 | -- |
| **Commit** | 8526a03 | 8526a03 |