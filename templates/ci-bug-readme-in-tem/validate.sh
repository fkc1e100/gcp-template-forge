#!/usr/bin/env bash
set -eo pipefail

echo "Waiting for hello-app deployment to be ready..."
kubectl rollout status deployment/hello-app --timeout=300s

echo "Verifying hello-app deployment is running..."
kubectl get pods -l app=hello

echo "Testing connectivity to hello-service..."
RESPONSE=$(kubectl run curl-test --image=curlimages/curl:8.4.0 --restart=Never --rm -i -- curl -s --connect-timeout 5 http://hello-service)
echo "Response from hello-service: $RESPONSE"

if [[ "$RESPONSE" == *"Hello, world!"* ]]; then
  echo "Success! The workload is serving traffic correctly."
  exit 0
else
  echo "Error: Unexpected response or connection failed."
  exit 1
fi
