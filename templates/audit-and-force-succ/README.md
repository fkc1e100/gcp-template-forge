# Audit and Force Success (Config Connector Path)

This path implements Epic #430 using Google Cloud Config Connector (KCC) manifests to deploy and manage a regional GKE cluster, custom network configuration, and standard workload infrastructure.

## Resources Created

### Infrastructure (KCC)
* **ComputeNetwork**: `audit-and-force-succ-net`
* **ComputeSubnetwork**: `audit-and-force-succ-sub` with custom secondary IP ranges for pods/services.
* **ContainerCluster**: `audit-and-force-succ-cls` (Workload Identity and regular release channel enabled).
* **ContainerNodePool**: `audit-and-force-succ-np` utilizing three explicit zone locations (`us-central1-a`, `us-central1-b`, `us-central1-c`) to fulfill regional cluster requirements.

### Workload (Raw K8s)
* **Deployment**: `audit-and-force-succ-web` running `nginx:stable-alpine`.
* **Service**: `audit-and-force-succ-svc` exposing the Deployment via standard LoadBalancer.

## Verification
`validate.sh` performs complete automated verification of the running application by polling for the exposed External LoadBalancer IP and asserting a successful HTTP 200 response.
