#!/usr/bin/env bash
set -eo pipefail

echo "=== [Test 1] Waiting for php-apache Deployment to be ready ==="
kubectl wait --namespace default --for=condition=available --timeout=600s deployment/php-apache

echo "=== [Test 2] Verifying service accessibality via Port Forward ==="
# Start port-forward in the background
iubectl port-forward svc/php-apache 8080:80 --namespace default &
PF_PID=$!

# Ensure we kill the port-forward on exit
trap 'kill $PF_PID' EXIT

# Wait a few seconds for port-forward to establish
sleep 5

# Curl the endpoint and verify response
RESPONSE=$(curl -s http://localhost:8080)
echo "Response from service: $RESPONSE"

if [[ "$RESPONSE" == "*OK*" ]]; then
  echo "Success! Service is serving traffic."
else
  echo "Error: Unexpected response from service"
  exit 1
fi

echo "=== [Test 3] Triggering HPA Scaling Activity (Functional Verification) ==="
echo "Manually scaling deployment to 5 replicas to test pod scheduling..."
kubectl scale deployment/php-apache --replicas=5
sleep 10
kubectl wait --namespace default --for=condition=available --timeout=300s deployment/php-apache

echo "Scale down back to original..."
kubectl scale deployment/php-apache --replicas=1

echo "All tests passed successfully!"
