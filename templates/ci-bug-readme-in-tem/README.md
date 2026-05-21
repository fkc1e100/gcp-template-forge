# CI Bug Readme in Tem

This template provisions a GKE cluster with a basic nginx workload using Google Cloud Config Connector (KCC).

## Architecture

The architecture deployed by this template contains:
- **Compute Network & Subnetwork**: A custom VPC and subnet with secondary IP ranges for pods and services.
- **ContainerCluster**: A GKE Regional cluster with Workload Identity enabled.
- **ContainerNodePool**: A regional node pool spanning multiple zones.
- **Nginx Deployment & Service**: A basic hello-world workload exposed via a LoadBalancer service.

## Usage

Apply the KCC manifests in the `config-connector/` directory to your KCC-enabled management cluster.
Once the GKE cluster is provisioned, apply the workloads in the `config-connector-workload/` directory to the newly created GKE cluster.
