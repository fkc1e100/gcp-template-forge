# Verification Plan - GKE LLM Inference

## Infrastructure Deployment

### Path 1: Terraform + Helm
```bash
cd templates/gke-llm-inference/terraform-helm
terraform init -backend-config="bucket=gke-gca-2025-forge-tf-state" -backend-config="prefix=templates/gke-llm-inference/terraform-helm"
terraform apply -auto-approve
```

### Path 2: Config Connector (KCC)
```bash
cd templates/gke-llm-inference/config-connector
kubectl apply -f network.yaml
kubectl apply -f cluster.yaml
kubectl apply -f bucket.yaml

# Wait for control plane (fast)
kubectl wait containerclusters gke-llm-inference-kcc -n forge-management \
  --for=condition=Ready --timeout=600s

# Wait for GPU node pool separately
kubectl wait containernodepools gke-llm-inference-kcc-gpu-pool -n forge-management \
  --for=condition=Ready --timeout=3600s

# Get credentials for the KCC cluster
gcloud container clusters get-credentials gke-llm-inference-kcc --region us-central1

# Verify actual node readiness
kubectl wait nodes -l cloud.google.com/gke-nodepool=gke-llm-inference-kcc-gpu-pool \
  --for=condition=Ready --timeout=3600s

# Apply workload
cd ../kcc-workload
kubectl apply -f manifests.yaml
```

## Validation

### 1. Pre-deployment Checks
```bash
# Check L4 quota in us-central1
gcloud compute regions describe us-central1 --format="value(quotas.filter(metric:NVIDIA_L4_GPUS).limit)"
```

### 2. Workload Health
```bash
# Wait for vLLM deployment to be ready (can take 15-20 mins for model load)
kubectl wait deployment release-deployment --for=condition=Available --timeout=1800s

# Check logs to see model loading status (initContainer)
kubectl logs -l app=vllm-inference-server -c model-loader -f

# Check logs to see vLLM server status (after initContainer completes)
kubectl logs -l app=vllm-inference-server -c inference-server -f
```

### 3. Inference Test
```bash
# Get LoadBalancer IP
EXTERNAL_IP=$(kubectl get svc release-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Send a test prompt
curl http://${EXTERNAL_IP}/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "/data/Qwen/Qwen2.5-1.5B-Instruct",
    "prompt": "Say hello!",
    "max_tokens": 10
  }'
```

## Teardown

### Terraform
```bash
terraform destroy -auto-approve
```

### KCC
```bash
kubectl delete -f manifests.yaml
kubectl delete -f bucket.yaml
kubectl delete -f cluster.yaml
kubectl delete -f network.yaml
```
