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
# Apply KCC manifests (GCP resources) to forge-management namespace on management cluster
kubectl apply -f config-connector/ -n forge-management
```

### Verification
1. **Resource Readiness:**
   ```bash
   kubectl wait --for=condition=Ready containercluster/enterprise-gke-kcc -n forge-management --timeout=20m
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

## Validation Output
Both deployment paths have been successfully verified in the project-standard CI pipeline (Run ID: 24675755295 and subsequent re-triggers).

### Final Results:
- **Terraform + Helm**: ✅ PASSED (Provisioning, Workload Readiness, WI Integration, LB Endpoint)
- **Config Connector**: ✅ PASSED (Resource Readiness, WI Integration via fallback, Helm-based validation)

Functional parity for Master Authorized Networks is confirmed.
