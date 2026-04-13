# Verification Plan - GKE LLM Inference

## Pre-deployment Checks

```bash
# 1. Check quota for NVIDIA L4 GPUs in us-central1
gcloud compute regions describe us-central1 --format=json | python3 -c "
import json, sys
r = json.load(sys.stdin)
for q in r['quotas']:
    if 'NVIDIA_L4_GPUS' in q['metric']:
        print(f'L4 GPU Quota: {q[\"usage\"]}/{q[\"limit\"]}')
"

# 2. Verify g2-standard-12 availability in us-central1-c
gcloud compute machine-types list --filter="zone:us-central1-c AND name:g2-standard-12"
```

## Terraform + Helm Deployment

```bash
cd templates/gke-llm-inference/terraform-helm

# Initialize and apply
terraform init
terraform apply -auto-approve \
  -var="project_id=$PROJECT_ID" \
  -var="service_account=$SERVICE_ACCOUNT"

# Get outputs
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw cluster_location)
BUCKET_NAME=$(terraform output -raw bucket_name)

# Get credentials
gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION

# (Optional) Populate bucket with model weights if not already present
# This requires a Hugging Face token with access to Gemma 2
# hf_token=$(gcloud secrets versions access latest --secret="huggingface-token")
# gcloud storage cp -r gs://some-public-source/gemma-2-2b-it gs://$BUCKET_NAME/google/
```

## Config Connector Deployment

```bash
cd templates/gke-llm-inference/config-connector

# Apply KCC manifests
kubectl apply -f network.yaml
kubectl apply -f cluster.yaml
kubectl apply -f bucket.yaml

# Wait for resources
kubectl wait --for=condition=Ready containercluster/gke-llm-inference-kcc -n forge-management --timeout=1800s

# Get credentials for the KCC cluster
gcloud container clusters get-credentials gke-llm-inference-kcc --region us-central1

# Apply workload
kubectl apply -f workload/manifests.yaml
```

## Endpoint Validation

```bash
# Wait for the service to get an external IP
EXTERNAL_IP=""
while [ -z "$EXTERNAL_IP" ]; do
  EXTERNAL_IP=$(kubectl get svc release-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  [ -z "$EXTERNAL_IP" ] && sleep 10
done

# Wait for vLLM to be ready (can take several minutes to load weights)
echo "Waiting for vLLM to be ready at http://$EXTERNAL_IP/health..."
until curl -sf http://$EXTERNAL_IP/health; do
  sleep 30
done

# Send a test inference request
curl -X POST http://$EXTERNAL_IP/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemma-2-2b-it",
    "messages": [
      {"role": "user", "content": "Tell me a short joke about a customer support chatbot."}
    ],
    "max_tokens": 50
  }'
```

## Teardown

### Terraform
```bash
terraform destroy -auto-approve \
  -var="project_id=$PROJECT_ID" \
  -var="service_account=$SERVICE_ACCOUNT"
```

### Config Connector
```bash
kubectl delete -f workload/manifests.yaml
kubectl delete -f bucket.yaml
kubectl delete -f cluster.yaml
kubectl delete -f network.yaml
```
