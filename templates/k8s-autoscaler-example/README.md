# GKE Autoscaling Example

This template provisions a GKE cluster with node pool autoscaling and a HorizontalPodAutoscalier (HPA) for standard workloads.

## Architecture

The architecture consists of:
- A VPC Network and a Subnetwork.
- A GKE Standard cluster (regional) with an autoscaling-enabled node pool.
- A Hello World deployment with a HorizontalPodAutoscalier (HPA) to auto-scale the application pods.
