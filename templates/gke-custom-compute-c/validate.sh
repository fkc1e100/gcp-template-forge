#!/bin/bash
set -eo pipefail

echo "=== START VALIDATION ==="

# 1. Get cluster credentials
echo "Configuring kubectl..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" --zone "${ZONE}" --project "${PROJECT_ID}"

# 2. Web service deployment check
echo "Waiting for custom-workload deployment to become available..."
kubectl rollout status deployment/custom-workload --timeout=10m

# 3. Wait for LoadBalancer external IP
echo "Waiting for dynamic LoadBalancer external IP assignment..."
EXTERNAL_IP=""
for i in {1..30}; do
  EXTERNAL_IP=$(kubectl get svc custom-workload -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || true)
  if [ -n "$EXTERNAL_IP" ]; then
    echo "Assigned External IP: ${EXTERNAL_IP}"
    break
  fi
  echo "Still waiting for External IP ($i/30)..."
  sleep 10
done

if [ -z "$EXTERNAL_IP" ]; then
  echo "ERROR: Service LoadBalancer External IP was not assigned in time."
  exit 1
fi

# 4. Perform functional validation (Curl the endpoint)
echo "Curling the service at http://${EXTERNAL_IP}..."
SUCCESS=false
for i in {1..12}; do
  if curl --silent --fail --max-time 5 "http://${EXTERNAL_IP}" > /dev/null; then
    echo "SUCCESS: Connection established to http://${EXTERNAL_IP} and valid HTTP response received!"
    SUCCESS=true
    break
  fi
  echo "Service not ready yet, retrying in 5 seconds ($i/12)..."
  sleep 5
done

if [ "$SUCCESS" = "false" ]; then
  echo "ERROR: Failed to curl the application endpoint."
  exit 1
fi

echo "=== VALIDATION SUCCESSFUL ==="
