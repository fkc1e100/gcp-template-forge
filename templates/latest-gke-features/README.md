# Template: Latest GKE Features Template

<!-- force CI run 2 -->

## Overview
This template demonstrates some of the latest and most advanced features of Google Kubernetes Engine (GKE), released in 2024, 2025, and 2026. It showcases both cluster-level infrastructure improvements and modern workload deployment patterns.

## Latest Features Included

### Cluster Features (Terraform)
- **GKE Gateway API**: Enabled by default (`CHANNEL_STANDARD`), providing a modern, expressive way to manage load balancing.
- **Node Pool Auto-provisioning (NAP)**: Automatically creates and manages node pools based on workload requirements.
- **Image Streaming (GCFS)**: Significantly reduces container startup times by streaming image data on-demand.
- **Enterprise Security Posture**: Advanced vulnerability scanning and security monitoring.
- **Spot VMs**: Cost-optimized compute for fault-tolerant workloads.

### Workload Features (Helm)
- **Native Sidecar Containers**: Leveraging Kubernetes 1.29+ "Sidecar Containers" feature (init containers with `restartPolicy: Always`).
- **GKE Gateway Controller**: Using `Gateway` and `HTTPRoute` resources instead of legacy Ingress.
- **Pod Topology Spread Constraints**: Modern scheduling to ensure high availability across hostnames and zones.

## Template Paths

### Terraform + Helm (`terraform-helm/`)
- Provisions a VPC-native, private GKE Standard cluster with NAP and Gateway API enabled.
- Deploys a workload that utilizes native sidecars and is exposed via GKE Gateway.

### Config Connector (`config-connector/`)
- Demonstrates a Kubernetes-native way to provision the core infrastructure (VPC, Cluster, NodePool).
- *Note: Some cutting-edge features like Gateway API configuration in the cluster spec may be limited in KCC depending on the version.*

## Performance & Cost Estimates

| Resource | Config | Estimated cost |
|---|---|---|
| Node pool | e2-standard-4 (NAP managed), spot | ~$0.04/hr |
| Load balancer | GKE Gateway (L7 GCLB) | ~$0.025/hr |
| **Total (estimated)** | | **~$0.07/hr** |

## Validation Record

|  | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | validating (GKE 1.35.2-gke.1485000) | validating (GKE 1.35.2-gke.1485000) |
| **Date** | 2026-04-17 | 2026-04-17 |
<!-- force CI run 3 -->
Re-triggering validation for latest-gke-features
<!-- force CI run 4 -->
