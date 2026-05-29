#!/usr/bin/env bash
set -euo pipefail

echo "=== Waiting for deployment to be ready ==="
kubectl rollout status deployment/audit-and-force-succ-web --timeout=300s

echo "=== Waiting for LoadBalancer External IP ==="
EXTERNAL_IP=""
for i in {1..30}; do
  EXTERNAL_IP=$(kubectl get svc audit-and-force-succ-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [ -n "$EXTERNAL_IP" ]; then
    break
  fi
  echo "Waiting for load balancer IP... (attempt $i/30)"
  sleep 10
done

if [ -z "$EXTERNAL_IP" ]; then
  echo "ERROR: Failed to obtain External IP for Service"
  exit 1
fi

echo "=== Found External IP: $EXTERNAL_IP ==="

echo "=== Testing application connectivity ==="
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 http://"$EXTERNAL_IP" || true)
if [ "$RESPONSE" != "200" ]; then
  echo "ERROR: Expected HTTP 200, got $RESPONSE"
  exit 1
fi

echo "=== SUCCESS: Workload is serving traffic successfully ==="
