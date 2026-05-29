# GKE Topology-Aware Routing

This template provisions a regional Google Kubernetes Engine (GKE) cluster and deploys a test workload spread evenly across multiple availability zones. It configures a Kubernetes Service with Topology-Aware Routing (Topology Aware Hints) enabled, demonstrating how GKE routes traffic natively to keep it within the same zone when possible, thereby reducing cross-zone egress costs and latency.

## Architecture
- **ComputeNetwork & ComputeSubnetwork**: VPC-native networking setup for GKE.
- **ContainerCluster**: A regional GKE cluster in `us-central1` with Dataplane V2 enabled (ADVANCED_DATAPATH).
- **ContainerNodePool**: A node pool spanning across all zones in the region.
- **Deployment**: A 6-replica NGINX deployment enforcing a 1-skew topology spread constraint across zones.
- **Service**: A ClusterIP service with `service.kubernetes.io/topology-mode: Auto` to automatically assign endpoint hints based on the deployment spread.

## Validation
The validation script confirms the workload is deployed and asserts that the `EndpointSlice` controller successfully populated the `hints` fields for the endpoints, indicating topology-aware routing is active.
