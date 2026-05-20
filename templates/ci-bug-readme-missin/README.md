# Kubernetes Autoscaling Example on GKE (Config Connector)

This template demonstrates how to set up and configure Kubernetes Autoscaling on Google Kubernetes Engine (GKE) using Config Connector (KCC).

## Architecture

The template provisions the following resources:
- A custom VPC and Subnetwork.
- A regional GKE Cluster with GCS FUSE CSI driver enabled.
- A regional Node Pool with GKE Cluster Autoscaler enabled (`autoscaling` block).
- A sample workload (`php-apache`) with a `HorizontalPodAutoscaler` (HPA) to autoscale pods based on CPU utilization.

## Directory Structure

- `config-connector/`: Contains GCP infrastructure resources (VPC, Subnet, GKE Cluster, and Node Pool).
- `config-connector-workload/`: Contains Kubernetes-native workloads (Deployment, Service, and HPA).
- `validate.sh`: Functional validation script to verify deployment readiness and service availability.

## Usage

1. Deploy the GCP Infrastructure:
   ```bash
   kubectl apply -f config-connector.
   ```J2. Wait for the GKE cluster and node pool to be ready:
   ```bash
   kubectl wait --for=condition=Ready containercluster/ci-bug-readme-missin-cluster
   ```
3. Deploy the application workkload:
   ```bash
   kubectl apply -f config-connector-workload/
   ```
4. Run validation:
   ```bash
   ./validate.sh
   ```