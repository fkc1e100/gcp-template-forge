#!/usr/bin/env bash
set -eo pipefail

echo "========================================="
echo "Starting functional validation of workload"
echo "========================================="

echo "Waiting for hello-nginx deployment to be ready..."
kubectl rollout status deployment/hello-nginx --timeout=10m

echo "Waiting for hello-nginx-service LoadBalancer IP..."
EXTERNAL_IP=""
for i in {1..60}; do
  EXTERNAL_IP=$(kubectl get svc hello-nginx-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [ -n "$EXTERNAL_IP" ]; then
    echo "Found LoadBalancer IP: $EXTERNAL_IP"
    break
  fi
  echo "Still waiting for LoadBalancer IP... (attempt $i/60)"
  sleep 10
done

if [ -z "$EXTERNAL_IP" ]; then
  echo "Error: Failed to obtain LoadBalancer IP within timeout"
  exit 1
fi

echo "Verifying service is accessible and serving traffic..."
success=false
for i in {1..12}; do
  if curl --connect-timeout 5 -sSf "http://${EXTERNAL_IP}" > /dev/null; then
    echo "Success: hello-nginx-service is up and reachable!"
    success=true
    break
  fi
  echo "Service not reachable yet, retrying... (attempt $i/12)"
  sleep 10
done

if [ "$success" = false ]; then
  echo "Error: Failed to connect to hello-nginx-service"
  exit 1
fi

echo "========================================="
echo "Validation completed successfully!"
echo "========================================="
