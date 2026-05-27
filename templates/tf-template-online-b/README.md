# tf-template-online-b

Deploy the microservice-based Google Cloud Online Boutique on GKE using Terraform + Helm.

## Infrastructure Created

- VPC and Custom Subnetwork
- GKE Zonal Standard Cluster
- GKE Node Pool of `e2-standard-4` instances (No spot, standard scheduling to guarantee stability)
- Microservices deployment via Helm Chart

## Validation

The validation script waits for GKE cluster availability, waits for all key services to be fully scheduled and available, then queries the GKE External LoadBalancer IP to verify that the Online Boutique frontend is serving successfully.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| project_id | The GCP project ID to deploy resources into | n/a |
| region | The GCP region to deploy to | us-central1 |
| zone | The GCP zone to deploy to | us-central1-a |
| cluster_name | The name of the GKE cluster (CI provided) | n/a |
| network_name | The name of the VPC network (CI provided) | n/a |
| subnet_name | The name of the subnet (CI provided) | n/a |
| uid_suffix | The unique suffix for resource names (CI provided) | n/a |
| service_account | The service account email to associate with GKE nodes | n/a |

