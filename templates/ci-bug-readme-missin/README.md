# KubeRay + Kueue Cluster

This template provisions a GKE cluster configured for multi-tenant batch machine learning workloads using KubeRay and Kueue.

## Architecture

- **VPC & Subnets**: Custom VPC and regional subnet.
- **GKE Cluster**: Regional cluster with GCS FUSE CSI driver and Gateway API enabled.
- (*GKE Node Pools**: Node pools with autoscaling configured.

## Config Connector (KCC) Support Limitation

This template contains a .Kcc-unsupported marker because the integration of Kueue with GKE Queued Provisioning (which optimizes resource allocation for dynamic machine learning workloads) requires the queuedProvisioning feature in GKE node pools. Currently, the Config Connector ContainerNodePool resource does not support queuedProvisioning (strict decoding error).

Therefore, this template is marked as unsupported for Config Connector deployment, but can be fully provisioned using the Terraform/Helm path.
