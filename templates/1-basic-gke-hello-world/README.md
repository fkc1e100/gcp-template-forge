# Basic GKE Cluster with Hello World Deployment

This template provisions a basic GKE Autopilot cluster and deploys a "Hello World" application.

## Architecture
- **VPC & Subnet:** Isolated networking for the cluster.
- **GKE Autopilot:** A fully managed GKE cluster for reduced operational overhead.
- **Workload:** A simple `hello-app` deployment exposed via a LoadBalancer.

## Prerequisites
- Google Cloud SDK (`gcloud`)
- Terraform (>= 1.0)
- `kubectl`

## Deployment

### 1. Provision Infrastructure
```bash
cd terraform
terraform init
terraform apply -var="project_id=YOUR_PROJECT_ID"
```

### 2. Deploy Application
```bash
# Get credentials for kubectl
gcloud container clusters get-credentials basic-gke-cluster --region us-central1 --project YOUR_PROJECT_ID

# Apply manifests
kubectl apply -f ../manifests/hello-world.yaml
```

## Validation
You can use the provided validation script to verify the deployment:
```bash
./scripts/validate.sh YOUR_PROJECT_ID us-central1 basic-gke-cluster
```

## Cleanup
To destroy the resources:
```bash
cd terraform
terraform destroy -var="project_id=YOUR_PROJECT_ID"
```
