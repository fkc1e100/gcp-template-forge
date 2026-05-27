# Online Boutique Microservices on GKE via Config Connector

This template provisions a Google Kubernetes Engine (GKE) cluster, Custom VPC Network, and subnets using **Google Cloud Config Connector (KCC)**. Once the infrastructure is ready, it deploys Google Cloud's official microservices demo app (**Online Boutique**) onto the newly created cluster.

## Architecture

1. **Infrastructure**:
   - `ComputeNetwork`: Dedicated Custom VPC.
   - `ComputeSubnetwork`: Private subnets.
   - `ContainerCluster`: Private GKE cluster.
   - `ContainerNodePool`: A high-availability node pool utilizing `e2-standard-4` machines.

2. **Microservices Workloads**:
   - Includes 11 microservices (adservice, frontend, cartservice, paymentservice, redis-cart database, and more).
   - Frontend is exposed using a standard Kubernetes service of type `LoadBalancer` for external access.

## Validating the Workloads

The `validate.sh` script does the following:
1. Waits for all 11 microservice deployments to achieve an `available` status in GKE.
2. Polls for the external IP address assigned to the `frontend-external` LoadBalancer.
3. Performs a functional validation check by calling `curl` on the endpoint and confirming that the returned HTML includes the "Online Boutique" banner.
