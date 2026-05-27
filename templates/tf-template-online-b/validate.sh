#!/usr/bin/env bash
set -eo pipefail

echo "===================================================="
echo "Starting validation for tf-template-online-b"
echo "===================================================="

# Check for required env vars
if [[ -z "$TF_VAR_cluster_name" || -z "$TF_VAR_zone" || -z "$TF_VAR_project_id" ]]; then
  echo "Error: TF_VAR_cluster_name, TF_VAR_zone, and TF_VAR_project_id must be set."
  exit 1
fi

echo "Retrieving GKE credentials..."
gcloud container clusters get-credentials "$TF_VAR_cluster_name" --zone "$TF_VAR_zone" --project "$TF_VAR_project_id"

echo "Waiting for all deployments to be ready..."
kubectl wait --namespace default --for=condition=available --timeout=600s deployment/frontend
kubectl wait --namespace default --for=condition=available --timeout=600s deployment/productcatalogservice
kubectl wait --namespace default --for=condition=available --timeout=600s deployment/cartservice

echo "Retrieving Frontend service external IP..."
EXTERNAL_IP=""
MAX_ATTEMPTS=40
for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  EXTERNAL_IP=$(kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [[ -n "$EXTERNAL_IP" ]]; then
    echo "Found external IP: $EXTERNAL_IP"
    break
  fi
  echo "Waiting for external IP (attempt $i/$MAX_ATTEMPTS)..."
  sleep 10
done

if [[ -z "$EXTERNAL_IP" ]]; then
  echo "Error: Frontend external IP could not be resolved."
  exit 1
fi

echo "Performing functional verification..."
CURL_SUCCESS=false
for ((i=1; i<=15; i++)); do
  echo "Curling external IP (attempt $i/15)..."
  RESPONSE=$(curl -sf "http://$EXTERNAL_IP" || true)
  if [[ "$RESPONSE" == *"Online Boutique"* ]]; then
    echo "Success: Online Boutique frontend is serving correctly!"
    CURL_SUCCESS=true
    break
  fi
  sleep 5
done

if [ "$CURL_SUCCESS" = false ]; then
  echo "Error: Did not receive expected response from Online Boutique frontend."
  exit 1
fi

echo "All tests passed successfully!"
