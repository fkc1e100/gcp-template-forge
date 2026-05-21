# GKE Kubernetes Autoscaler Template

This template sets up a Google Kubernetes Engine (GKE) cluster with auto-scaling capabilities.

## Architecture

The architecture of this setup includes:
- **Compute Network & Subnetwork**: Configured VPC and subnet custom-designed for the GKE cluster.
- **GKE Cluster**: A regional GKE cluster with Cluster Autoscaler enabled, allowing dynamic node pool scaling.
- **Node Pools**: Auto-scaling node pools that adjust size based on resource demands.
- **Horizontal Pod Autoscaling (HPA)**: Pre-configured workloads with HPA to scale pods dynamically based on CPU/memory utilization.

## Usage

1. Deploy the GKE cluster using the provided configuration.
2. Deploy the sample workloads and verify horizontal pod autoscaling and cluster autoscaling under load.
