#!/usr/bin/env bash
set -eo pipefail

echo "===================================================="
echo "Starting Validation for kcc-template-online"
echo "===================================================="

# Test 1: Verify cluster credentials exist
echo "Checking cluster connectivity..."
kubectl cluster-info

# Test 2: Wait for deployment rollout
echo "Waiting for kcc-template-online-frontend deployment to be ready..."
kubectl rollout status deployment/kcc-template-online-frontend --timeout=300s

# Test 3: Verify pods are Running
echo "Checking pod status..."
kubectl get pods -l app=kcc-template-online-frontend

# Test 4: Wait for dynamic service LoadBalancer IP structure
echo "Waiting for LoadBalancer IP to be assigned..."
LB_IP=""
for i in {1..30}; do
  LB_IP=$(kubectl get svc kcc-template-online-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [ -n "$LB_IP" ]; then
    echo "LoadBalancer IP successfully provisioned: ${LB_IP}"
    break
  fi
  echo "Still waiting for LoadBalancer IP ($i/30)..."
  sleep 10
done

if [ -z "$LB_IP" ]; then
  echo "Error: Timeout waiting for LoadBalancer IP assignment."
  exit 1
fi

# Test 5: Functional Verification (Must prove standard workload works, not just that pods are running!)
echo "Performing functional verification Curl of GKE endpoint..."
curl_success=false
for i in {1..15}; do
  echo "Attempting to contact the online app front-end ($i/15)..."
  RESPONSE=$(curl -sSf http://${LB_IP} || true)
  if [[ "$RESPONSE" == *"Welcome to"* || "$RESPONSE" == *"KCC Online"* ]]; then
    echo "Success! Received expected healthy payload from the GKE web app front-end."
    curl_success=true
    break
  fi
  sleep 5
done

if [ "$curl_success" = false ]; then
  echo "Error: Verification failed. Could not verify response from the GKE web service."
  exit 1
fi

echo "===================================================="
echo "Validation completed successfully!"
echo "===================================================="
