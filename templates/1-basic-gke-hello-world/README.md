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

3. Plan the deployment:
   ```bash
   terraform plan -var="project_id=gca-gke-2025"
   ```

4. Apply the changes:
   ```bash
   terraform apply -var="project_id=gca-gke-2025"
   ```

   > **Note:** Configuring the Kubernetes provider using attributes from a cluster created in the same state can sometimes cause issues during the initial `plan`. For production, we recommend separating infrastructure and workload management.

## Deployment (Config Connector)

1. Ensure you have Config Connector installed in your cluster or are using Google Cloud Config Controller.

2. Replace `gca-gke-2025` in the manifests with your actual GCP project ID:
   ```bash
   # On macOS/Linux
   find kcc/ -type f -exec sed -i 's/gca-gke-2025/your-actual-project-id/g' {} +
   ```

3. Apply the manifests:
   ```bash
   kubectl apply -f kcc/
   ```

4. Monitor the resource status:
   ```bash
   kubectl wait --for=condition=Ready containercluster hello-world-cluster
   ```

5. Wait for the Service external IP:
   ```bash
   # It may take a few minutes for the LoadBalancer IP to be assigned
   kubectl get service -n hello-world hello-world-service --watch
   ```

## Verification

After the deployment is complete, you can find the external IP of the hello-world service.

**For Terraform:**
```bash
terraform output hello_world_service_ip
```

**For KCC:**
```bash
kubectl get service -n hello-world hello-world-service
```

Access the application in your browser at `http://<external_ip>`.

## Cleanup

**For Terraform:**
```bash
terraform destroy -var="project_id=gca-gke-2025"
```

**For KCC:**
```bash
kubectl delete -f kcc/
```

