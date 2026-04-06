# Enterprise GKE Cluster and Workload Template

This template provides an Enterprise-grade Google Kubernetes Engine (GKE) cluster via Google Cloud Config Connector (KCC) manifests, and a corresponding production-ready Helm chart workload.

## Features

### GKE Cluster
- **Regional Deployment:** High availability across zones (`location: us-central1`).
- **Private Cluster:** Nodes with internal IP addresses only.
- **Workload Identity:** Allows Kubernetes service accounts to act as Google IAM service accounts without downloading keys.
- **Network Policies:** Enforces network boundaries and isolation.
- **Binary Authorization:** Enforces signature validation and trusted container registries.
- **Security Posture & Monitoring:** Deep integration with Google Cloud Operations Suite and the Security Posture Dashboard.

### Workload (Helm Chart)
- **High Availability:** Pod Anti-Affinity, Horizontal Pod Autoscaler (HPA), and Pod Disruption Budgets (PDB).
- **Security Context:** Runs as a non-root user (UID 1000), drops ALL Linux capabilities, and uses a read-only root filesystem.
- **Probes:** Configured Liveness and Readiness probes.
- **Resource Limits:** Defined CPU and Memory requests/limits.
- **Secrets Management:** Integrates with Google Secret Manager via the Secrets Store CSI driver.
- **Network Policy:** Restricts ingress and egress traffic at the pod level.

## Usage

1. **Configure KCC Manifests:**
   - Update `YOUR_PROJECT_ID` in `cluster/cluster.yaml` and `cluster/nodepool.yaml`.
   - Update the network and subnetwork references.
   - Apply the cluster manifests:
     ```sh
     kubectl apply -f cluster/
     ```

2. **Deploy the Workload:**
   - Modify values in `workload/values.yaml` (e.g., project ID, service account details).
   - Install using Helm:
     ```sh
     helm install enterprise-app ./workload -f workload/values.yaml
     ```
