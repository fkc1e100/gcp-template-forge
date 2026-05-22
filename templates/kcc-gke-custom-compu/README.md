# GKE Custom Compute via Config Connector (KCC)

This template configures custom compute hardware (machine types) for GKE workload execution using Google Cloud Config Connector.

## Created Resources

- **VPC Network & Subnet** (`ComputeNetwork`, `ComputeSubnetwork`)
- **GKE Cluster** (`ContainerCluster`) configured with Workload Identity
- **Node Pool** (`ContainerNodePool`) configured with custom machine type `e2-custom-4-8192` specifying explicit `nodeLocations`
- **Kubernetes Workload** (`Deployment` & `Service` of type `LoadBalancer`)

## Validation

The functional validation script `validate.sh` ensures that:
1. Target cluster authentication is successful.
2. The deployed application rolls out cleanly.
3. The LoadBalancer registers an external IP and is functional, returning HTTP `200` upon testing.
