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

## Cluster Details
- **Type**: GKE Standard
- **Release channel**: REGULAR
- **Node pools**: primary-node-pool (e2-standard-4, spot nodes)
- **Networking**: VPC-native, Private nodes, dedicated VPC per issue

## Workload Details
- **Application**: Nginx-based production-ready workload
- **Access**: LoadBalancer / ClusterIP
- **Dependencies**: Google Secret Manager (via Secrets Store CSI), IAM Workload Identity

## Enabled Features
- [x] Workload Identity
- [x] VPC-native networking
- [x] Private cluster
- [x] Binary Authorization
- [x] Security Posture Monitoring
- [x] Pod Anti-Affinity
- [x] HPA / PDB
- [x] Config Connector resources: ContainerCluster, ContainerNodePool, ComputeNetwork, ComputeSubnetwork, IAMServiceAccount, IAMPolicyMember
