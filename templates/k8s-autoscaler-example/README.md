# Kubernetes Autoscaler Example

This template demonstrates how to deploy a Kubernetes application with autoscaling enabled.

## Prerequisites

*   A Google Cloud project
*   A Kubernetes cluster
*   kubectl installed and configured to connect to your cluster
*   gcloud CLI installed and configured to connect to your project

## Deployment

1.  Clone this repository.
2.  Navigate to the `templates/k8s-autoscaler-example` directory.
3.  Run `gcloud container clusters get-credentials <cluster-name> --zone <cluster-zone> --project <project-id>` to configure kubectl to connect to your cluster.
4.  Run `terraform init` to initialize the Terraform working directory.
5.  Run `terraform apply` to deploy the application.

## Architecture

The application consists of the following components:

*   A Deployment that runs the application pods.
*   A Service that exposes the application to the outside world.
*   A Horizontal Pod Autoscaler (HPA) that automatically scales the number of pods based on CPU utilization.

## Configuration

The following variables can be configured in the `terraform.tfvars` file:

*   `project_id`: The ID of your Google Cloud project.
*   `cluster_name`: The name of your Kubernetes cluster.
*   `cluster_zone`: The zone where your Kubernetes cluster is located.
*   `image`: The Docker image to use for the application pods.
*   `min_replicas`: The minimum number of replicas to run.
*   `max_replicas`: The maximum number of replicas to run.
*   `target_cpu_utilization`: The target CPU utilization percentage.

## Testing

1.  Send traffic to the application.
2.  Observe the HPA scaling the number of pods up and down based on CPU utilization.

## Cleanup

Run `terraform destroy` to destroy the application.
