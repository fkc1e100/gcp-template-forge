# GKE Hello World Template

This template creates a basic GKE cluster and deploys a simple "hello world" application to it.

## Features
- Standard GKE Cluster with a managed node pool.
- Kubernetes deployment with 2 replicas of the `hello-app` image.
- LoadBalancer service to expose the application.

## Prerequisites
- Terraform >= 1.0
- Google Cloud Platform account with appropriate permissions.

## Deployment
1. Initialize Terraform: `terraform init`
2. Apply the configuration: `terraform apply -var="project_id=YOUR_PROJECT_ID"`

## Outputs
- `cluster_name`: The name of the GKE cluster.
- `service_ip`: The external IP address of the hello world service.
