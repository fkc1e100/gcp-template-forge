# Enterprise GKE Cluster and Workload Template

This template provides an Enterprise-grade Google Kubernetes Engine (GKE) cluster via Google Cloud Config Connector (KCC) manifests, and a corresponding production-ready Helm chart workload.

## Architecture

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

## Prerequisites

1. Config Connector installed and configured on your management cluster.
2. A GCP Project with required APIs enabled (Container, Compute, Secret Manager, Binary Authorization).
3. Secret Manager CSI driver installed on the newly created cluster.

## Deployment Instructions

1. **Deploy the Cluster (KCC):**
   - Update `YOUR_PROJECT_ID` in `cluster/cluster.yaml` and `cluster/nodepool.yaml`.
   - Apply the cluster manifests to your management cluster:
     ```bash
     kubectl apply -f cluster/
     ```

2. **Deploy the Workload:**
   - Modify values in `workload/values.yaml` (e.g., project ID, service account details).
   - Install using Helm on the target cluster:
     ```bash
     helm install enterprise-app ./workload -f workload/values.yaml
     ```
