#!/usr/bin/env bash
set -eo pipefail

echo "===================================================="
echo "Validating GKE Custom Compute Template (KCC Path)..."
echo "===================================================="

CLUSTER_NAME="kcc-gke-custom-compu-cluster"
REGION="us-central1"
PROJECT_ID="gca-gke-2025"

echo "Acquiring credentials for cluster ${CLUSTER_NAME} in region ${REGION}..."
for i in {1..6}; do
  if gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${REGION}" --project "${PROJECT_ID}"; then
    echo "Got cluster credentials successfully!"
    break
  fi
  echo "Waiting for cluster to become ready... (attempt $i/6)"
  sleep 25
done

echo "Waiting for hello-custom-compute deployment to roll out..."
kubectl rollout status deployment/hello-custom-compute --timeout=300s

echo "Retrieving External IP of hello-custom-compute-service..."
EXTERNAL_IP=""
for i in {1..30}; do
  EXTERNAL_IP=$(kubectl get svc hello-custom-compute-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || true)
  if [ -n "$EXTERNAL_IP" ]; then
    echo "LoadBalancer External IP acquired: $EXTERNAL_IP"
    break
  fi
  echo "Waiting for LoadBalancer IP... (attempt $i/30)"
  sleep 10
done

if [ -z "$EXTERNAL_IP" ]; then
  echo "ERROR: Could not retrieve Service LoadBalancer IP."
  exit 1
fi

echo "Verifying endpoint response..."
HTTP_CODE=""
for i in {1..10}; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://${EXTERNAL_IP}" || true)
  if [ "$HTTP_CODE" = "200" ]; then
    echo "SUCCESS: Endpoint is responding correctly with HTTP 200!"
    break
  fi
  echo "Endpoint did not respond with 200 (Result: $HTTP_CODE). Retrying... (attempt $i/10)"
  sleep 5
done

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: Service verification failed. Endpoint is unresponsive."
  exit 1
fi

echo "===================================================="
echo "GKE Custom Compute Validation Completed Successfully!"
echo "===================================================="
