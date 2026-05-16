#!/usr/bin/env bash
set -euo pipefail

echo "Running validation for feat-implement-proac..."

echo "Test 1: Verify cluster access"
kubectl get nodes

echo "Test 2: Verify workload namespaces"
kubectl get ns

echo "Test 3: Wait for workload pods to be running"
kubectl wait --for=condition=ready pod -l app=watcher-service --timeout=300s

echo "Test 4: Wait for LoadBalancer IP"
SVC_IP=""
for i in {1..30}; do
  SVC_IP=$(kubectl get svc watcher-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [ -n "$SVC_IP" ]; then
    echo "LoadBalancer IP: $SVC_IP"
    break
  fi
  echo "Waiting for LoadBalancer IP... ($i/30)"
  sleep 10
done

if [ -z "$SVC_IP" ]; then
  echo "Error: LoadBalancer IP not provisioned."
  exit 1
fi

echo "Test 5: Functional verification"
echo "Curling watcher service at http://${SVC_IP}:80..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${SVC_IP}:80")

if [ "$HTTP_STATUS" != "200" ]; then
  echo "Error: Expected HTTP 200, got ${HTTP_STATUS}"
  exit 1
fi

echo "Success! Watcher Service is responding with HTTP 200."
