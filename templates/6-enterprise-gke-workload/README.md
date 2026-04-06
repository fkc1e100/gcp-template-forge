# Enterprise Grade GKE Cluster and Workload

This template provides an Enterprise-ready GKE configuration and a sample workload demonstrating production best practices.

## Architecture Highlights

### GKE Cluster (KCC Manifests)
- **Regional Deployment**: Multi-zone high availability for the control plane and node pools.
- **Private Cluster**: Nodes have only internal IP addresses. Master authorized networks are enabled to restrict control plane access.
- **Workload Identity**: Securely access GCP services from Kubernetes pods without downloading long-lived JSON keys.
- **Network Policies**: Enabled to provide granular pod-to-pod communication control.
- **Binary Authorization**: Ensures only trusted, signed container images are deployed.
- **Cloud Monitoring & Logging**: Deeply integrated with Google Cloud Operations Suite for system and workload logs.
- **Security Posture Dashboard**: Advanced security reporting for misconfigurations and vulnerabilities.

### Enterprise Workload (Helm Chart)
- **High Availability**: 3 replicas with Pod Disruption Budgets (PDB) and pod anti-affinity rules.
- **Resource Management**: Explicit CPU and Memory requests and limits.
- **Security Hardening**:
    - Runs as a non-root user.
    - Read-only root filesystem.
    - Dropped all unnecessary Linux capabilities.
- **Health Probes**: Configured Liveness and Readiness probes for self-healing and zero-downtime deployments.
- **Configuration & Secrets**:
    - **ConfigMap**: For non-sensitive application settings.
    - **Secret Manager CSI Driver**: Securely injects secrets into the workload from Google Cloud Secret Manager using Workload Identity.

## Deployment Instructions

### Prerequisites
1.  **Google Cloud Project**: A GCP project with Config Connector (KCC) installed and configured to manage resources in the target project.
2.  **Kubectl**: Configured to point to the KCC management cluster.
3.  **Helm**: For deploying the workload.

### 1. Provision the GKE Cluster
Apply the KCC manifests in the `cluster/` directory:
```bash
kubectl apply -f cluster/
```
Wait for resources to be ready:
```bash
kubectl wait --for=condition=Ready containercluster/enterprise-cluster --timeout=20m
kubectl wait --for=condition=Ready containernodepool/primary-pool --timeout=15m
```

### 2. Deploy the Workload
Once the cluster is ready, configure your kubectl to point to the **newly created enterprise cluster** and deploy the Helm chart:
```bash
helm install enterprise-workload ./workload/
```

## Security Validation
This architecture has been validated for:
- [x] Zero external IP addresses for worker nodes.
- [x] Functional Workload Identity binding for secret access.
- [x] Correct enforcement of Pod Disruption Budgets during node maintenance.
- [x] Compliance with non-root security contexts.
