#!/usr/bin/env bash
set -xeo pipefail

# Required environment variables (set by CI):
# - TF_VAR_project_id
# - TF_VAR_region
# - TF_VAR_zone
# - TF_VAR_cluster_name

echo "Configuring kubectl for GKE cluster: ${TF_VAR_cluster_name} in ${TF_VAR_region}"
gcloud container clusters get-credentials "${TF_VAR_cluster_name}" \
    --region "${TF_VAR_region}" \
    --project "${TF_VAR_project_id}"

# Verify GKE nodes are ready
echo "Checking nodes..."
kubectl get nodes

# Deploy Helm workload
echo "Installing/Upgrading Helm workload..."
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helm upgrade --install audit-workload "${DIR}/terraform-helm/workload" --namespace default --wait --timeout 10m

# Wait for Pods to be ready
echo "Waiting for Deployment/audit-workload to be ready..."
kubectl rollout status deployment/audit-workload --timeout=5m

# Wait for Service LoadBalancer external IP
echo "Waiting for LoadBalancer IP..."
counter=0
max_attempts=30
SERVICE_IP=""
while [ $counter -lt $max_attempts ]; do
    SERVICE_IP=$(kubectl get svc audit-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || true)
    if [ -n "$SERVICE_IP" ]; then
        echo "Found LoadBalancer IP: ${SERVICE_IP}"
        break
    fi
    echo "Waiting for external IP (attempt $((counter+1))/${max_attempts})..."
    sleep 10
    counter=$((counter+1))
done

if [ -z "$SERVICE_IP" ]; then
    echo "Failed to get Service LoadBalancer IP"
    exit 1
fi

# Curl the endpoint to verify it works (Functional validation)
echo "Verifying service access..."
curl_response=""
counter=0
while [ $counter -lt 12 ]; do
    curl_response=$(curl -sf "http://${SERVICE_IP}" || true)
    if [[ "$curl_response" == *"Welcome to nginx!"* ]]; then
        echo "Success: Nginx is serving traffic!"
        break
    fi
    echo "Service is not yet responding successfully. Waiting 10 seconds..."
    sleep 10
    counter=$((counter+1))
done

if [[ ! "$curl_response" == *"Welcome to nginx!"* ]]; then
    echo "Verification failed! Service response did not match expected criteria."
    exit 1
fi

echo "All tests passed successfully!"
