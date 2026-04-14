# Verification Plan: GKE vLLM Staging

## Pre-Deployment Checks
```bash
# Check quota for L4 GPUs
gcloud compute regions describe us-central1 --project=gca-gke-2025 --format=json | jq '.quotas[] | select(.metric == "PREEMPTIBLE_NVIDIA_L4_GPUS")'
```

## Terraform + Helm Path
1. **Deploy:**
   ```bash
   cd templates/gke-vllm-staging/terraform-helm
   terraform init -backend-config="bucket=gke-gca-2025-forge-tf-state" -backend-config="prefix=templates/gke-vllm-staging/terraform-helm"
   terraform apply -auto-approve
   ```
2. **Verify:**
   ```bash
   # Wait for staging job (up to 60 min)
   kubectl wait --for=condition=complete job/model-staging-job --timeout=3600s
   
   # Wait for vLLM pod
   kubectl wait pod -l app.kubernetes.io/name=gke-vllm-staging --for=condition=Ready --timeout=300s
   
   # Check health
   SERVICE_IP=$(kubectl get svc -l app.kubernetes.io/name=gke-vllm-staging -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
   curl -sf http://$SERVICE_IP:8000/health
   ```
3. **Destroy:**
   ```bash
   terraform destroy -auto-approve
   ```

## Config Connector Path
1. **Apply:**
   ```bash
   kubectl apply -n forge-management -f templates/gke-vllm-staging/config-connector/
   ```
2. **Wait:**
   ```bash
   # Wait for control plane
   kubectl wait containerclusters gke-vllm-staging-kcc -n forge-management --for=condition=Ready --timeout=600s
   ```
3. **Delete:**
   ```bash
   kubectl delete -n forge-management -f templates/gke-vllm-staging/config-connector/
   ```
