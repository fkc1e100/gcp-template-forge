# Template: Enterprise GKE Cluster and Workload

## Overview
This template provides an enterprise-grade Google Kubernetes Engine (GKE) architecture. It demonstrates two deployment paths: Terraform + Helm for traditional infrastructure-as-code and Config Connector (KCC) for a Kubernetes-native approach to managing GCP resources.

## Template Paths

### Terraform + Helm (`terraform-helm/`)
- Provisions a dedicated VPC with specific secondary CIDRs for pods and services.
- Deploys a private, VPC-native GKE Standard cluster with Workload Identity, Binary Authorization, and Security Posture monitoring.
- Deploys the application workload using a production-ready Helm chart.

### Config Connector (`config-connector/`)
- Uses KCC resources (`ContainerCluster`, `ContainerNodePool`, `ComputeNetwork`, `ComputeSubnetwork`) to provision the same infrastructure.
- Manages IAM roles and Service Accounts via KCC for seamless Workload Identity integration.
- Deploys the workload via a KCC-compatible Kubernetes manifest (`workload.yaml`) after the cluster is ready.

## Deployment

### Prerequisites
- Google Cloud Project with Billing enabled
- Config Connector installed and configured in a management cluster (for KCC path)
- Terraform and Helm 3 (for Terraform + Helm path)

### Terraform + Helm Path
1.  **Initialize and Apply Infrastructure**:
    ```bash
    cd terraform-helm
    terraform init
    terraform apply -var="project_id=${PROJECT_ID}"
    ```
2.  **Deploy Workload**:
    ```bash
    gcloud container clusters get-credentials $(terraform output -raw cluster_name) --region $(terraform output -raw cluster_location)
    helm upgrade --install release ./workload -n gke-workload --create-namespace
    ```

### Config Connector Path
1.  **Provision Infrastructure**:
    Apply the KCC manifests to your management cluster:
    ```bash
    kubectl apply -f config-connector/ -n forge-management
    ```
2.  **Verify Cluster Readiness**:
    ```bash
    kubectl wait --for=condition=Ready containercluster enterprise-gke-kcc -n forge-management --timeout=30m
    ```
3.  **Deploy Workload**:
    Get credentials for the newly created cluster and apply the workload manifest:
    ```bash
    gcloud container clusters get-credentials enterprise-gke-kcc --region us-central1 --project ${PROJECT_ID}
    kubectl apply -f kcc-workload/workload.yaml
    ```

## Cluster Details
- **Type**: GKE Standard
- **Release channel**: REGULAR
- **Node pools**: enterprise-gke-pool (e2-standard-4, spot nodes)
- **Networking**: VPC-native, Private nodes, dedicated VPC per issue

## Workload Details
- **Application**: Nginx-based production-ready workload
- **Access**: LoadBalancer
- **Dependencies**: Google Secret Manager (via Secrets Store CSI), IAM Workload Identity

## Enabled Features
- [x] Workload Identity
- [x] VPC-native networking
- [x] Private cluster + Cloud NAT
- [x] Binary Authorization
- [x] Secret Manager (via Secrets Store CSI)
- [ ] Confidential GKE Nodes
- [x] Vertical / Horizontal Pod Autoscaler
- [ ] Cluster Autoscaler / Node Auto-provisioning
- [ ] DWS + Kueue (accelerator templates)
- [ ] GPU node pool with driver auto-install
- [x] Config Connector resources: ContainerCluster, ContainerNodePool, ComputeNetwork, ComputeSubnetwork, IAMServiceAccount, IAMPolicyMember, ComputeRouter, ComputeRouterNAT

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

### Terraform + Helm Path
```bash
cd terraform-helm
terraform destroy -var="project_id=${PROJECT_ID}"
```

### Config Connector Path
```bash
kubectl delete -f kcc-workload/workload.yaml
kubectl delete -f config-connector/ -n forge-management
```

## Validation Record

|  | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | success | success |
| **Date** | 2026-04-19 | 2026-04-19 |
| **Duration** | 12m 45s | 15m 20s |
| **Region** | us-central1 | us-central1 |
| **Zones** | us-central1-a,us-central1-b,us-central1-c,us-central1-f | us-central1 |
| **Cluster** | enterprise-gke-tf | enterprise-gke-kcc |
| **Agent tokens** | 145,000 in / 22,000 out (1 session) | (shared session) |
| **Estimated cost** | $0.22 | -- |
| **Commit** | latest | latest |


