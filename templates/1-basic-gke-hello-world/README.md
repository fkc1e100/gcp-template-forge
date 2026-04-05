# Basic GKE Cluster with Hello World Deployment

This template provisions a basic GKE Standard cluster and deploys a simple hello-world application.

## Resources Created

- VPC Network and Subnetwork
- GKE Standard Cluster with a single node pool (e2-medium Spot nodes)
- Dedicated Service Account for GKE Nodes
- Kubernetes Namespace: `hello-world`
- Kubernetes Deployment: `hello-world` (using `google-samples/hello-app:1.0`)
- Kubernetes Service: `hello-world-service` (Type: `LoadBalancer`)

## Infrastructure as Code Options

This template provides two ways to deploy the infrastructure:

1.  **Terraform:** Standard Terraform configurations located in the root of this template directory.
2.  **Config Connector (KCC):** Kubernetes-native manifests located in the `kcc/` directory. These can be used with Google Cloud Config Controller or a GKE cluster with Config Connector installed.

## Deployment (Terraform)

1. Authenticate with Google Cloud:
   ```bash
   gcloud auth application-default login
   ```

2. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Plan the deployment:
   ```bash
   terraform plan -var="project_id=YOUR_PROJECT_ID"
   ```

3. Apply the changes:
   ```bash
   terraform apply -var="project_id=YOUR_PROJECT_ID"
   ```

## Verification

After the deployment is complete, you can find the external IP of the hello-world service in the Terraform outputs:

```bash
terraform output hello_world_service_ip
```

Access the application in your browser at `http://<hello_world_service_ip>`.
