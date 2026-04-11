# Verification Plan - Enterprise GKE

This plan outlines the steps to verify both the Terraform + Helm and Config Connector deployment paths.

## Pre-deployment Checks

Run the following script to verify quota and availability:

```bash
#!/bin/bash
# pre_check.sh
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
   gcloud container clusters describe cluster-issue-6 --region us-central1 --format="value(status)"
   ```
2. **Workload Health:**
   ```bash
   gcloud container clusters get-credentials cluster-issue-6 --region us-central1
   kubectl get pods -l app.kubernetes.io/name=workload-6 -n workload-6
   ```
3. **Endpoint Interaction:**
   ```bash
   # Get LoadBalancer IP
   SERVICE_IP=$(kubectl get svc workload-6 -o jsonpath='{.status.loadBalancer.ingress[0].ip}' -n workload-6)
   curl -sf http://${SERVICE_IP}:8080/
   ```

### Teardown
```bash
terraform destroy -auto-approve
```

## Path 2: Config Connector

### Deployment
```bash
# Apply KCC manifests to forge-management namespace on management cluster
kubectl apply -R -f config-connector/ -n forge-management
```

### Verification
1. **Resource Readiness:**
   ```bash
   kubectl wait --for=condition=Ready containercluster/cluster-issue-6-kcc -n forge-management --timeout=20m
   ```
2. **Workload Identity:**
   ```bash
   # Handled by validate.sh
   ./validate.sh
   ```

### Teardown
```bash
kubectl delete -R -f config-connector/ -n forge-management
```

## Validation Output
(To be populated after successful CI run)
