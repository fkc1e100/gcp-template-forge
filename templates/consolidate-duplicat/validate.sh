#!/usr/bin/env bash
set -eo pipefail

echo "=== [TEST 1] Verifying cluster nodes are up and active ==="
kubectl get nodes -o wide

echo "=== [TEST 2] Verifying workload deployment status ==="
kubectl wait --namespace default --for=condition=available --timeout=300s deployment/hello-app

echo "=== [TEST 3] Waiting for LoadBalancer External IP ==="
EXTERNAL_IP=""
for i in {1..30}; do
  EXTERNAL_IP=$(kubectl get svc hello-service -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [ -n "$EXTERNAL_IP" ]; then
    break
  fi
  echo "Waiting for loadbalancer external IP... ($i/30)"
  sleep 10
done

if [ -z "$EXTERNAL_IP" ]; then
  echo "ERROR: Failed to obtain LoadBalancer external IP for hello-service"
  exit 1
fi
echo "Service external IP obtained: $EXTERNAL_IP"

echo "=== [TEST 4] Functional Verification: Sending request to workload ==="
RESPONSE_VALID=false
for i in {1..12}; do
  RESPONSE=$(curl -s -m 5 "http://$EXTERNAL_IP" || true)
  if echo "$RESPONSE" | grep -q "Hello, world!"; then
    RESPONSE_VALID=true
    break
  fi
  echo "Waiting for valid response from http://$EXTERNAL_IP ... ($i/12)"
  sleep 10
done

if [ "$RESPONSE_VALID" = true ]; then
  echo "SUCCESS: Workload validation succeeded! Received expected response."
else
  echo "ERROR: Validation failed. Response did not match expected structure."
  exit 1
fi
