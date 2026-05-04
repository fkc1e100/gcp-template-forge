# Multi-Tenant Ray on GKE with Kueue

This template provisions a GKE cluster configured for multi-tenant batch workloads using **KubeRay** and **Kueue** (Equitable Queuing).

## Architecture
- **GKE Cluster**: Regional cluster with Workload Identity enabled.
- **Node Pools**: 
  - `system-pool`: Standard node pool for system operators.
  - `ray-pool`: Scalable worker pool with `queued_provisioning` enabled for strict integration with Kueue batch semantics.
- **Workloads**:
  - `Kueue`: Installed via Helm for resource quota management.
  - `KubeRay`: Installed via Helm for `RayCluster` and `RayJob` lifecycle management.
  
## Deployment Paths

### Terraform + Helm (`terraform-helm/`)
Provisions the GKE infrastructure via Terraform, and then verifies the Kueue/KubeRay ecosystem via `validate.sh`. 
The validation script sequentially installs the operators to honor required CRD dependencies and runs a functional Python `RayJob` through the `LocalQueue`.

### Config Connector (`config-connector/`)
The KCC path is tracked separately or relies on specific capabilities. Please note that GKE `queued_provisioning` lacks full KCC support natively, so standard standard autoscaling limits are applied as equivalents in KCC forms.
