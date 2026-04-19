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
   gcloud container clusters describe basic-gke-hello-world --region us-central1 --format="value(status)"
   ```
2. **Workload Health:**
   ```bash
   gcloud container clusters get-credentials basic-gke-hello-world --region us-central1
   kubectl get pods -l app.kubernetes.io/name=hello-world -n default
   ```
3. **Endpoint Interaction:**
   ```bash
   # Get LoadBalancer IP
   SERVICE_IP=$(kubectl get svc -l app.kubernetes.io/name=hello-world -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' -n default)
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
   kubectl wait --for=condition=Ready containercluster/basic-gke-hello-world -n forge-management --timeout=20m
   ```
2. **Workload Deployment & Integration:**
   The `validate.sh` script handles the verification of the workload and performs interaction tests.
   ```bash
   ./validate.sh
   ```

### Teardown
```bash
# Delete KCC manifests (GCP resources)
kubectl delete -f config-connector/ -n forge-management
```
