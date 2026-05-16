#!/usr/bin/env bash
set -eo pipefail

echo "==> Fetching credentials for KCC cluster..."
CLUSTER_NAME="kcc-template-online-cluster"
REGION="us-central1"
PROJECT_ID="gca-gke-2025"

gcloud container clusters get-credentials "${CLUSTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}"

echo "==> Verifying Online Boutique Deployment..."
kubectl wait --for=condition=available --timeout=600s deployment/frontend || {
    echo "Frontend deployment failed to become available"
    kubectl get pods
    exit 1
}

echo "==> Waiting for Frontend LoadBalancer IP..."
for i in {1..30}; do
  FRONTEND_IP=$(kubectl get svc frontend-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [ -n "$FRONTEND_IP" ]; then
    break
  fi
  echo "Waiting for LoadBalancer IP..."
  sleep 10
done

if [ -z "$FRONTEND_IP" ]; then
  echo "ERROR: Frontend LoadBalancer IP not found."
  kubectl get svc
  exit 1
fi

echo "Frontend IP: $FRONTEND_IP"

echo "==> Testing HTTP Endpoint..."
for i in {1..30}; do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://${FRONTEND_IP} || true)
  if [ "$HTTP_STATUS" == "200" ]; then
    echo "SUCCESS: Online Boutique is serving HTTP 200"
    exit 0
  fi
  echo "Waiting for HTTP 200 (current: $HTTP_STATUS)..."
  sleep 10
done

echo "ERROR: Online Boutique failed to serve HTTP 200"
exit 1
