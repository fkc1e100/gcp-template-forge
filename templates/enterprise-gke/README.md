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
- Deploys the workload via the Helm chart (located in `terraform-helm/workload/`) after the cluster is ready.

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

## Validation Record

|  | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | success | skipped |
| **Date** | 2026-04-11 | 2026-04-11 |
| **Duration** | 9m 39s | n/a |
| **Region** | us-central1 | us-central1 (KCC cluster) |
| **Zones** | us-central1-a,us-central1-b,us-central1-c,us-central1-f | forge-management namespace |
| **Cluster** | basic-gke-tf | krmapihost-kcc-instance |
| **Agent tokens** | 120,000 in / 15,000 out (1 session) | (shared session) |
| **Estimated cost** | $0.18 | -- |
| **Commit** | 2c375256 | 2c375256 |

<!-- force CI run 3 -->
