# Verification Plan - Basic GKE Hello World

This plan outlines the steps to verify both the Terraform + Helm and Config Connector deployment paths.

## Path 1: Terraform + Helm

### Deployment
```bash
cd terraform-helm/
terraform init
terraform apply -auto-approve
```

### Verification
1. **Cluster Health:**
   ```bash
   gcloud container clusters describe basic-gke-tf --region us-central1 --format="value(status)"
   ```
2. **Workload Health:**
   ```bash
   gcloud container clusters get-credentials basic-gke-tf --region us-central1
   kubectl get pods -l app.kubernetes.io/name=hello-world -n hello-world
   ```
3. **Endpoint Interaction:**
   ```bash
   # Get LoadBalancer IP
   SERVICE_IP=$(kubectl get svc basic-gke-hello-world -o jsonpath='{.status.loadBalancer.ingress[0].ip}' -n hello-world)
   curl -sf http://${SERVICE_IP}:80/
   ```

### Teardown
```bash
terraform destroy -auto-approve
```

## Path 2: Config Connector

### Deployment
```bash
# Apply KCC manifests (GCP resources) to forge-management namespace on management cluster
kubectl apply -f config-connector/ -n forge-management
```

### Verification
1. **Resource Readiness:**
   ```bash
   kubectl wait --for=condition=Ready containercluster/basic-gke-kcc -n forge-management --timeout=20m
   ```
2. **Workload Deployment & Integration:**
   The `validate.sh` script handles the deployment of the workload via Helm to the newly created cluster and performs interaction tests.
   ```bash
   ./validate.sh
   ```

### Teardown
```bash
# Delete KCC manifests (GCP resources)
kubectl delete -f config-connector/ -n forge-management
```
