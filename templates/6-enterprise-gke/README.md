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
- Workload manifests are located in the `workload/` subdirectory.

## Cluster Details
- **Type**: GKE Standard
- **Release channel**: REGULAR
- **Node pools**: pool-issue-6 (e2-standard-4, spot nodes)
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
