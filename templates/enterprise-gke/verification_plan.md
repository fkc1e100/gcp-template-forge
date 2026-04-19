# Verification Plan - Enterprise GKE

This plan outlines the steps to verify both the Terraform + Helm and Config Connector deployment paths.

## Pre-deployment Checks

Run the following script to verify quota and availability:

```bash
#!/bin/bash
# pre_check.sh
# UPDATE: Replace 'gca-gke-2025' with your actual GCP Project ID
PROJECT_ID="gca-gke-2025"
REGION="us-central1"

echo "Checking quota for ${PROJECT_ID} in ${REGION}..."
gcloud compute regions describe ${REGION} \
  --project=${PROJECT_ID} --format=json \
  | python3 -c "
import json, sys
r = json.load(sys.stdin)
for q in r['quotas']:
    if q['limit'] > 0 and q['usage'] / q['limit'] > 0.80:
        print(f'WARNING: {q[\"metric\"]} at {q[\"usage\"]/q[\"limit\"]*100:.0f}% ({q[\"usage\"]:.0f}/{q[\"limit\"]:.0f})')
"

echo "Checking machine type availability..."
gcloud compute machine-types list \
  --filter="zone:${REGION}-b AND name=e2-standard-4" \
  --format="table(name,zone)"
```

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
   gcloud container clusters describe enterprise-gke-tf --region us-central1 --format="value(status)"
   ```
2. **Workload Health:**
   ```bash
   gcloud container clusters get-credentials enterprise-gke-tf --region us-central1
   kubectl get pods -l app.kubernetes.io/name=enterprise-workload -n gke-workload
   ```
3. **Endpoint Interaction:**
   ```bash
   # Get LoadBalancer IP
   SERVICE_IP=$(kubectl get svc -l app.kubernetes.io/instance=release -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' -n gke-workload)
   curl -sf http://${SERVICE_IP}:80/
   ```

### Teardown
```bash
terraform destroy -auto-approve
```

## Path 2: Config Connector

### Deployment
```bash
# 1. Apply KCC manifests (GCP resources) to forge-management namespace on management cluster
kubectl apply -f config-connector/ -n forge-management

# 2. Wait for cluster readiness
kubectl wait --for=condition=Ready containercluster/enterprise-gke-kcc -n forge-management --timeout=30m

# 3. Deploy Workload via KCC manifest
gcloud container clusters get-credentials enterprise-gke-kcc --region us-central1
kubectl apply -f kcc-workload/workload.yaml
```

### Verification
1. **Resource Readiness:**
   ```bash
   kubectl wait --for=condition=available deployment/release-enterprise-workload -n gke-workload --timeout=15m
   ```
2. **Workload Identity & Integration:**
   The `validate.sh` script handles the deep verification of Workload Identity, Service Accounts, and interaction tests.
   ```bash
   export CLUSTER_NAME="enterprise-gke-kcc"
   ./validate.sh
   ```

### Teardown
```bash
# 1. Delete workload
kubectl delete -f kcc-workload/workload.yaml

# 2. Delete KCC manifests (GCP resources)
kubectl delete -f config-connector/ -n forge-management
```

## Validation Output
(To be populated after successful CI run)
