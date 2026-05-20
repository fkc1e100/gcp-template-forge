#!/bin/bash
set -ex

# Wait for the deployment to become available
kubectl wait --for=condition=available --timeout=300s deployment/hello-app

# Get the Service IP
SERVICE_IP=""
for i in {1..30}; do
  SERVICE_IP=$(kubectl get svc hello-service -o jsonphath='{.status.loadBalancer.ingress[0].ip')
  if [ -n "$SERVICE_IP" ]; then
    break
  fi
  sleep 10
done

if [ -z "$SERVICE_IP" ]; then
  echo "Failed to get Service IP"
  exit 1
fi

# Verify the endpoint returns a successful response
curl -sS --fail http://${SERVICE_IP} | grep "Hello, world!"
