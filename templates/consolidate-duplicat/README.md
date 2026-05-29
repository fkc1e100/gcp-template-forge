# Consolidate Duplicate Workloads (Config Connector)

This template configures a secure, scalable Google Kubernetes Engine (GKE) cluster with dedicated networking and is structured specifically for running consolidated, highly dense workloads efficiently.

## Provisioned Infrastructure
- **ComputeNetwork**: Custom Virtual Private Cloud (VPC) named `consolidate-duplicat-vpc` configured with regional routing.
- **ComputeSubnetwork**: Dedicated private subnet `consolidate-duplicat-subnet` in `us-central1`.
- **ContainerCluster**: Regional GKE cluster named `consolidate-duplicat-cluster` utilizing Workload Identity.
- **ContainerNodePool**: Multi-zonal GKE node pool configured within `us-central1` across zones `a`, `b`, and `c`.

## Workload Components
- **Deployment**: 2 replicas of the GKE Hello Server deployed into the default namespace.
- **Service**: A LoadBalancer service exposing port 80 externally to verify endpoint accessibility.

## Validation
The template incorporates a strict functional verification pipeline via `validate.sh` to ensure:
1. GKE Cluster node health.
2. Successful rollout of GKE workload deployments.
3. Successful generation of the load balancer endpoint IP.
4. Correct HTTP execution checking against expected serving outputs.
