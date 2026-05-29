# GKE K8s RBAC Manager

This template provisions a GKE cluster with its associated networking infrastructure using Google Cloud Config Connector. 
It also deploys native Kubernetes RBAC configurations (ServiceAccount, ClusterRole, and ClusterRoleBinding) to demonstrate managing access controls in the cluster.

## Resources Provisioned
- **Network**: `ComputeNetwork` and `ComputeSubnetwork`
- **GKE**: `ContainerCluster` and `ContainerNodePool`
- **Workload**: A mock Deployment running via a specific `ServiceAccount`.
- **RBAC**: A `ClusterRole` granting restricted view access to standard resources, and a `ClusterRoleBinding` linking it to the `ServiceAccount`.

## Deployment
1. Apply the GCP infrastructure in `config-connector/` to your Config Connector management cluster.
2. Wait for the GKE cluster to be fully provisioned.
3. Authenticate to the newly created GKE cluster.
4. Apply the Kubernetes resources in `config-connector-workload/` directly to the newly provisioned GKE cluster.
5. Execute `validate.sh` to confirm the deployment and thoroughly test RBAC permissions.
