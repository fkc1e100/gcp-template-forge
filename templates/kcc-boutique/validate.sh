#!/usr/bin/env bash
set -eo pipefail

echo "Applying Online Boutique manifests..."
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/release/kubernetes-manifests.yaml

echo "Waiting for deployments to be available..."
kubectl wait --for=condition=Available deployment --all --timeout=600s

echo "Getting frontend external IP..."
EXTERNAL_IP=""
for i in {1..30}; do
  EXTERNAL_IP=$(kubectl get svc frontend-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  if [ -n "$EXTERNAL_IP" ]; then
    echo "Frontend External IP: $EXTERNAL_IP"
    break
  fi
  echo "Waiting for LoadBalancer IP..."
  sleep 10
done

if [ -z "$EXTERNAL_IP" ]; then
  echo "Failed to get frontend external IP"
  exit 1
fi

echo "Checking HTTP status..."
for i in {1..20}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$EXTERNAL_IP/")
  if [ "$STATUS" == "200" ]; then
    echo "Success! Online Boutique is returning HTTP 200."
    exit 0
  fi
  echo "HTTP status $STATUS, waiting 10s..."
  sleep 10
done

echo "Validation failed. Online Boutique is not returning HTTP 200."
exit 1
