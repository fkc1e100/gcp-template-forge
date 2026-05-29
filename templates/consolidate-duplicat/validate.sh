#!/usr/bin/env bash
set -euo pipefail

# Expected variables: CLUSTER_NAME, REGION, PROJECT_ID

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Configuring kubectl..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${REGION}" --project "${PROJECT_ID}"

echo "==> Deploying workload with Helm..."
helm upgrade --install consolidate-duplicat "${SCRIPT_DIR}/terraform-helm/workload" \
  --namespace default \
  --wait \
  --timeout 10m

echo "==> Waiting for deployment rollout..."
kubectl rollout status deployment/consolidate-duplicat-workload --namespace default --timeout=5m

echo "==> Fetching External IP of the service..."
IP=""
for i in {1..30}; do
  IP=$(kubectl get service consolidate-duplicat-workload -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [ -n "$IP" ]; then
    break
  fi
  echo "Waiting for External IP (attempt $i/30)..."
  sleep 10
done

if [ -z "$IP" ]; then
  echo "ERROR: Failed to get external IP for service"
  exit 1
fi

echo "==> External IP is $IP. Verifying workload functionality..."
success=false
for i in {1..12}; do
  echo "Testing connection (attempt $i/12)..."
  if curl -s -f -I "http://${IP}" > /dev/null; then
    echo "SUCCESS: Connection established, returned 200 OK!"
    success=true
    break
  fi
  sleep 10
done

if [ "$success" = false ]; then
  echo "ERROR: Could not get successful response from http://${IP}"
  exit 1
fi

echo "All verification checks passed successfully!"
