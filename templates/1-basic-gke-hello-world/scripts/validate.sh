#!/bin/bash
set -e

PROJECT_ID=$1
REGION=$2
CLUSTER_NAME=$3

if [ -z "$PROJECT_ID" ] || [ -z "$REGION" ] || [ -z "$CLUSTER_NAME" ]; then
  echo "Usage: $0 <project_id> <region> <cluster_name>"
  exit 1
fi

echo "Authenticating with cluster $CLUSTER_NAME in $REGION..."
gcloud container clusters get-credentials "$CLUSTER_NAME" --region "$REGION" --project "$PROJECT_ID"

echo "Waiting for hello-world deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/hello-world

echo "Waiting for LoadBalancer IP to be assigned..."
EXTERNAL_IP=""
MAX_RETRIES=30
RETRY_COUNT=0
while [ -z "$EXTERNAL_IP" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  EXTERNAL_IP=$(kubectl get service hello-world -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [ -z "$EXTERNAL_IP" ]; then
    echo "Still waiting for IP... (Attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
    sleep 10
    RETRY_COUNT=$((RETRY_COUNT+1))
  fi
done

if [ -z "$EXTERNAL_IP" ]; then
  echo "Timed out waiting for LoadBalancer IP."
  exit 1
fi

echo "Hello World app is available at: http://$EXTERNAL_IP"
echo "Testing connectivity..."
curl -s --head "http://$EXTERNAL_IP" | head -n 1

echo "Validation successful!"
