# GKE Topology-Aware Routing Template

This template demonstrates how to optimize cross-zone egress costs in GKE using **Topology-Aware Routing**.

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Overview

In multi-zonal GKE clusters, network traffic between pods in different zones incurs cross-zone egress charges. Topology-Aware Routing (via Topology-Aware Hints) allows Kubernetes to prefer routing traffic to endpoints within the same zone as the source pod.

## Key Features

- **Standard Multi-zonal GKE Cluster:** Regional cluster distributed across multiple zones.
- **Gateway API Enabled:** Uses the modern GKE Gateway controller.
- **Topology-Aware Hints:** Enabled on Kubernetes Services to keep traffic local to the zone.
- **Topology Spread Constraints:** Ensures workloads are evenly distributed across availability zones.

## Architecture

1.  **VPC Network & Subnet:** Configured for VPC-native GKE.
2.  **GKE Cluster:** Regional cluster with Gateway API enabled.
3.  **Frontend Microservice:** Deployed with 3 replicas, spread across 3 zones.
4.  **Backend Microservice:** Deployed with 3 replicas, spread across 3 zones.
5.  **Service Topology:** Both frontend and backend services have `service.kubernetes.io/topology-mode: Auto` enabled.

## Usage

### Terraform & Helm

1.  Initialize and apply the Terraform configuration:
    ```bash
    cd terraform-helm
    terraform init
    terraform apply
    ```

2.  The application workload is deployed via the Helm chart (located in `terraform-helm/workload/`) after the cluster is ready. This is handled automatically by the CI pipeline.

## Verification

The `verification_plan.md` provides detailed steps to verify that traffic is indeed staying within the same zone.
