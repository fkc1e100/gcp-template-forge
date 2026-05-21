# Online Boutique on GKE via Config Connector

This template provisions a GKE cluster and deploys the Google Cloud Online Boutique microservices demo using Google Cloud Config Connector (KCC).

## Architecture

- **Networking:** VPC network and subnetwork.
- **Compute:** Regional GKE cluster with an `e2-standard-4` node pool spread across three zones (`us-central1-a`, `us-central1-b`, `us-central1-c`).
- **Workload:** 11 microservices (frontend, checkout, catalog, recommendations, etc.) deployed to the GKE cluster.

## Deployment

Config Connector manifests are applied to the Config Control/management cluster:
- `config-connector/network.yaml`
- `config-connector/cluster.yaml`
- `config-connector/nodepool.yaml`

Once the GKE cluster is Ready, the Kubernetes workloads in `config-connector-workload/` are deployed onto the provisioned GKE cluster by the runner.
