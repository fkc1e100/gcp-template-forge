# Online Boutique on GKE (KCC)

This template provisions a GKE cluster via Config Connector and deploys the [Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo) microservices demo.

## Architecture
- **VPC & Subnet**: Regional network for GKE.
- **GKE Cluster**: Regional cluster with Dataplane V2 and Workload Identity.
- **Node Pool**: Scalable node pool (`e2-standard-4`) across three zones.
- **Workload**: The Online Boutique suite of e-commerce microservices.

## Paths
- `config-connector/`: KCC manifests for Google Cloud infrastructure.
- `config-connector-workload/`: Minimal workload placeholder. The actual workloads are fetched from the official repository during validation.
- `validate.sh`: Applies the official microservices-demo release manifests and validates the frontend LoadBalancer.
