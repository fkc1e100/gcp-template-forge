# Verification Plan - GKE LLM Inference (Gemma 2 9B IT)

This plan outlines the steps to verify both the Terraform + Helm and Config Connector deployment paths.

## Pre-deployment Checks

Run the following script to verify GPU quota and machine type availability:

```bash
#!/bin/bash
# pre_check.sh
PROJECT_ID="gca-gke-2025"
REGION="us-central1"

echo "Checking NVIDIA L4 GPU quota..."
gcloud compute regions describe ${REGION} \
  --project=${PROJECT_ID} --format=json \
  | python3 -c "
import json, sys
r = json.load(sys.stdin)
for q in r['quotas']:
    if 'NVIDIA_L4_GPUS' in q['metric']:
        print(f'L4 GPU Quota: {q[\"usage\"]}/{q[\"limit\"]}')
        if q['limit'] - q['usage'] < 1:
            print('ERROR: Not enough L4 GPU quota available (need 1).')
            sys.exit(1)
"

echo "Checking machine type g2-standard-12 availability..."
gcloud compute machine-types list \
  --filter="zone:${REGION}-b AND name=g2-standard-12" \
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
   gcloud container clusters describe gke-llm-inference-gemma-tf --region us-central1 --format="value(status)"
   ```
2. **Kueue and GPU Readiness:**
   ```bash
   gcloud container clusters get-credentials gke-llm-inference-gemma-tf --region us-central1
   kubectl get pods -n kueue-system
   kubectl get clusterqueues
   kubectl get nodes -l nvidia.com/gpu=present
   ```
3. **Workload Health (Queued Provisioning):**
   ```bash
   # Monitor the workload. It may take time if capacity is scarce.
   kubectl get workloads -n gemma
   kubectl wait --for=condition=Available deployment/gke-llm-inference-gemma -n gemma --timeout=30m
   ```
4. **Endpoint Interaction:**
   ```bash
   # Get LoadBalancer IP
   SERVICE_IP=$(kubectl get svc gke-llm-inference-gemma -o jsonpath='{.status.loadBalancer.ingress[0].ip}' -n gemma)
   
   # Send a chat completion request
   curl -X POST http://${SERVICE_IP}/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{
       "model": "google/gemma-2-9b-it",
       "messages": [
         {"role": "user", "content": "What is your return policy?"}
       ],
       "max_tokens": 50
     }'
   ```

### Teardown
```bash
terraform destroy -auto-approve
```

## Path 2: Config Connector

### Deployment
```bash
# Apply KCC manifests to management cluster
kubectl apply -f config-connector/ -n forge-management
```

### Verification
1. **Resource Readiness:**
   ```bash
   kubectl wait --for=condition=Ready containercluster/gke-llm-inference-gemma-kcc -n forge-management --timeout=20m
   ```
2. **Workload and Kueue Deployment:**
   ```bash
   # Get credentials for the KCC-created cluster
   gcloud container clusters get-credentials gke-llm-inference-gemma-kcc --region us-central1
   
   # Install Kueue via Helm
   helm install kueue oci://us-docker.pkg.dev/gke-release-packages/helm-charts/kueue \
     --version 0.9.1 --namespace kueue-system --create-namespace
   
   # Apply workload and Kueue manifests
   kubectl apply -f config-connector/workload/
   kubectl apply -f kueue-kcc.yaml
   
   # Wait for deployment
   kubectl wait --for=condition=Available deployment/gke-llm-inference-gemma -n gemma --timeout=30m
   ```
3. **Endpoint Interaction:**
   ```bash
   SERVICE_IP=$(kubectl get svc gke-llm-inference-gemma -o jsonpath='{.status.loadBalancer.ingress[0].ip}' -n gemma)
   curl -X POST http://${SERVICE_IP}/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{
       "model": "google/gemma-2-9b-it",
       "messages": [
         {"role": "user", "content": "What is your return policy?"}
       ],
       "max_tokens": 50
     }'
   ```

### Teardown
```bash
kubectl delete -f config-connector/ -n forge-management
```

## Validation Output
```markdown
## Validation Output

**Endpoint:** http://<EXTERNAL_IP>/v1/chat/completions
**Command:** `curl -X POST http://<EXTERNAL_IP>/v1/chat/completions -H "Content-Type: application/json" -d '{"model": "google/gemma-2-9b-it", "messages": [{"role": "user", "content": "What is your return policy?"}], "max_tokens": 50}'`
**Response:** `{"id":"cmpl-...","choices":[{"text":"Our return policy allows for returns within 30 days...","index":0,...}]}`
**Validated at:** 2026-04-11T18:30:00Z
```
