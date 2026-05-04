# Multi-Tenant Ray on GKE with Equitable Queuing

This template provisions a GKE cluster with Kueue and KubeRay to support multi-tenant Ray workloads with equitable queuing.

## Paths

### Terraform Path
The Terraform path (`terraform-helm/`) deploys the complete architecture:
* GKE Cluster
* Node Pools with `queued_provisioning` enabled
* Kueue and KubeRay operators via Helm

### Config Connector Path
The Config Connector path is **unsupported** for this template.

**Reason:** Kueue equitable queuing heavily relies on the `queuedProvisioning` feature on GKE node pools, which is not currently supported in KCC `ContainerNodePool` (`v1beta1`). Without this feature, node pools bypass the Kueue integration and autoscaler interactions for standard batch ML jobs.

See `agent-infra/kcc-capabilities.yaml` for more details.
