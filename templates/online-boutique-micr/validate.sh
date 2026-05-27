#!/usr/bin/env bash
set -eo pipefail

echo "Executing validate.sh..."

deployments=(
  "adservice"
  "cartservice"
  "checkoutservice"
  "currencyservice"
  "emailservice"
  "frontend"
  "paymentservice"
  "productcatalogservice"
  "recommendationservice"
  "shippingservice"
  "redis-cart"
)

echo "Waiting for all microservice deployments to become available..."
for dep in "${deployments[@]}"; do
  echo "Waiting for deployment: $dep..."
  kubectl wait --namespace default --for=condition=available "deployment/$dep" --timeout=300s
done

echo "All deployments are ready!"

# Polling for LoadBalancer External IP
echo "Waiting for frontend-external load balancer IP..."
EXTERNAL_IP=""
for i in {1..30}; do
  EXTERNAL_IP=$(kubectl get service frontend-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [ -n "$EXTERNAL_IP" ]; then
    break
  fi
  echo "Still waiting for LoadBalancer IP (attempt $i/30)..."
  sleep 10
done

if [ -z "$EXTERNAL_IP" ]; then
  echo "Error: Failed to obtain external IP for frontend-external service"
  kubectl get service frontend-external
  exit 1
fi

echo "Frontend LoadBalancer IP: $EXTERNAL_IP"

# Functional verification of web endpoint
echo "Performing functional verification curl test..."
HEALTHY=false
for i in {1..12}; do
  RESPONSE=$(curl -s -L --max-time 10 "http://$EXTERNAL_IP" || true)
  if echo "$RESPONSE" | grep -q "Online Boutique"; then
    echo "Success! Online Boutique frontend is fully functional and responding to web traffic."
    HEALTHY=true
    break
  fi
  echo "Waiting for healthy frontend HTML response (attempt $i/12)..."
  sleep 10
done

if [ "$HEALTHY" = "false" ]; then
  echo "Error: Functional verification failed. The frontend did not return the expected Online Boutique home page."
  exit 1
fi

echo "All tests successfully completed!"
