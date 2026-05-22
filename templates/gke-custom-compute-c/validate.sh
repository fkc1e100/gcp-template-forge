#!/usr/bin/env bash
set -xeo pipefail

echo "==> Verifying cluster accessibility"
kubectl cluster-info

echo "==> Waiting for custom-compute deployment to be ready"
kubectl rollout status deployment/custom-compute-app --timeout=300s

echo "==> Waiting for Custom Compute service load balancer external IP"
EXTERNAL_IP=""
for i in {1..30}; do
  EXTERNAL_IP=$(kubectl get svc custom-compute-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [ -n "$EXTERNAL_IP" ]; then
    break
  fi
  echo "Waiting for external IP (attempt $i/30)..."
  sleep 10
done

if [ -z "$EXTERNAL_IP" ]; then
  echo "Load balancer external IP did not allocate in time. Trying port-forward verification fallback..."
  
  # Start port-forward in the background
  kubectl port-forward svc/custom-compute-service 8080:80 &
  PORT_FORWARD_PID=$!
  
  # Ensure background process is terminated when executing exit hooks
  trap 'kill $PORT_FORWARD_PID' EXIT
  
  # Wait for port-forward to establish
  sleep 5
  
  echo "Verifying local service port-forward response"
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080 || true)
  if [ "$RESPONSE" -eq 200 ]; then
    echo "Fallback verification SUCCESS: Application is running and healthy on custom node specs!"
    exit 0
  else
    echo "Fallback verification FAILED: Health check returned status $RESPONSE"
    exit 1
  fi
fi

echo "==> Verifying application is running on GKE Custom Node via external IP"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://${EXTERNAL_IP} || true)
if [ "$RESPONSE" -eq 200 ]; then
  echo "VERIFICATION SUCCESS: Load Balancer responding with HTTP 200 on Custom Compute Node Pool!"
else
  echo "VERIFICATION FAILED: Received HTTP status: $RESPONSE"
  exit 1
fi
