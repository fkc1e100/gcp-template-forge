#!/usr/bin/env bash
set -euo pipefail

echo "====================================================================="
echo "  Validation Script for progress-tracker (KCC path)"
echo "====================================================================="

echo "Waiting for Deployment to be available..."
kubectl wait --for=condition=available --timeout=300s deployment/progress-tracker

echo "Waiting for LoadBalancer IP..."
ITER=0
MAX_ITER=30
while true; do
  ENDPOINT_IP=$(kubectl get svc progress-tracker-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [ -n "$ENDPOINT_IP" ]; then
    echo "LoadBalancer IP assigned: $ENDPOINT_IP"
    break
  fi
  if [ $ITER -ge $MAX_ITER ]; then
    echo "Timeout waiting for LoadBalancer IP."
    exit 1
  fi
  echo "Waiting 10s for IP..."
  sleep 10
  ITER=$((ITER+1))
done

# Functional test: Test 5
echo "Testing application endpoint (Test 5: Functional Verification)..."
MAX_HTTP_ITER=12
HTTP_ITER=0
SUCCESS=0

while [ $HTTP_ITER -lt $MAX_HTTP_ITER ]; do
  echo "Curling http://$ENDPOINT_IP/ ..."
  RESPONSE=$(curl -s -m 5 http://$ENDPOINT_IP/ || true)
  if echo "$RESPONSE" | grep -q "resumed"; then
    echo "Success! Response received: $RESPONSE"
    SUCCESS=1
    break
  fi
  echo "No valid response yet. Retrying in 10 seconds..."
  sleep 10
  HTTP_ITER=$((HTTP_ITER+1))
done

if [ $SUCCESS -eq 0 ]; then
  echo "Failed to get valid response from workload."
  exit 1
fi

echo "All tests passed successfully!"
