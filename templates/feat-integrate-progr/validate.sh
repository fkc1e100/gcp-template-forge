#!/usr/bin/env bash
set -euo pipefail

echo "Running validation for feat-integrate-progr..."

echo "Waiting for Deployment to be available..."
kubectl wait --for=condition=available --timeout=300s deployment/dashboard-ui

echo "Waiting for LoadBalancer IP provisioning..."
LB_IP=""
for i in {1..40}; do
  IP=$(kubectl get svc dashboard-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [ -n "$IP" ]; then
    LB_IP="$IP"
    echo "LoadBalancer IP discovered: $LB_IP"
    break
  fi
  echo "Still waiting for LoadBalancer IP... ($i/40)"
  sleep 15
done

if [ -z "$LB_IP" ]; then
  echo "ERROR: Failed to retrieve LoadBalancer IP."
  exit 1
fi

echo "Functional Test 1: Querying root HTTP endpoint..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$LB_IP/")
if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: Expected HTTP 200 on root endpoint, got HTTP $HTTP_CODE"
  exit 1
fi
echo "Root endpoint returned HTTP 200 OK."

echo "Functional Test 2: Verifying SSE stream on /events..."
SSE_DATA=$(curl -s --max-time 10 "http://$LB_IP/events")

if echo "$SSE_DATA" | grep -q 'data:'; then
  echo "SUCCESS: Found SSE stream content in response."
  echo "Response sample: $SSE_DATA"
else
  echo "ERROR: Did not find 'data:' marker in SSE endpoint output."
  echo "Response received: $SSE_DATA"
  exit 1
fi

echo "All functional validations passed successfully!"
