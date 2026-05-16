# Online Boutique on GKE (Config Connector)

Deploys the Online Boutique microservices demo on GKE.

## Paths
- **Config Connector:** Fully implemented, provisions a GKE cluster and node pool using `ContainerCluster` and `ContainerNodePool` custom resources. Applies the microservices manifest to the provisioned cluster.
- **Terraform:** Implemented in the `terraform-helm` directory (see separate issue).

## Validation
`validate.sh` ensures the `frontend-external` LoadBalancer service is accessible and returns HTTP 200.
