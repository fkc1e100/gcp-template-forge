#!/usr/bin/env bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# validate.sh for Online Boutique

set -euo pipefail

echo "=== Validation: Online Boutique ==="

PROJECT_ID="${PROJECT_ID:-gca-gke-2025}"
CLUSTER_NAME="${CLUSTER_NAME:-online-boutique-gke-tf}"
REGION="${REGION:-us-central1}"
NAMESPACE="${NAMESPACE:-default}"

# Isolate kubeconfig
export KUBECONFIG
KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# ── 1. Cluster Connectivity ───────────────────────────────────────────────────
echo "--- Test 1: Cluster Connectivity ---"
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --region "${REGION}" --project "${PROJECT_ID}"
kubectl cluster-info
kubectl get nodes -o wide
echo "PASS: Cluster is reachable."

# ── 2. Node Readiness ─────────────────────────────────────────────────────────
echo "--- Test 2: Node Readiness ---"
kubectl wait nodes --all --for=condition=Ready --timeout=10m
echo "PASS: All nodes are Ready."

# ── 3. Workload Deployment Readiness ─────────────────────────────────────────
echo "--- Test 3: Workload Deployment Readiness ---"
# We check for the frontend deployment as the primary indicator
kubectl wait deployment \
  -l app=frontend \
  -n "${NAMESPACE}" \
  --for=condition=available \
  --timeout=30m
kubectl get pods -n "${NAMESPACE}" -l app=frontend -o wide
echo "PASS: Workload Deployment is Available."

# ── 4. Pod Log Sanity Check ───────────────────────────────────────────────────
echo "--- Test 4: Pod Log Sanity ---"
POD=$(kubectl get pod -n "${NAMESPACE}" -l app=frontend \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -z "$POD" ]; then
  echo "ERROR: No Running pod found matching label app=frontend in namespace ${NAMESPACE}"
  exit 1
fi
echo "Checking logs for pod $POD (last 20 lines)..."
kubectl logs "$POD" -n "${NAMESPACE}" --tail=20
echo "PASS: Pod is running and producing logs."

# ── 5. Workload Functional Verification ──────────────────────────────────────
echo "--- Test 5: Workload Functional Verification ---"

SERVICE_IP=""
for i in $(seq 1 30); do
  SERVICE_IP=$(kubectl get svc -n "${NAMESPACE}" frontend-external \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  [ -n "$SERVICE_IP" ] && break
  echo "Waiting for LoadBalancer IP (attempt $i/30)..."
  sleep 20
done

if [ -z "$SERVICE_IP" ]; then
  echo "ERROR: LoadBalancer IP not assigned after 10 minutes"
  kubectl get svc -n "${NAMESPACE}"
  exit 1
fi

echo "LoadBalancer IP: ${SERVICE_IP}"
echo "Curling frontend..."
for i in $(seq 1 12); do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 --max-time 15 "http://${SERVICE_IP}/" || echo "000")
  if [[ "$HTTP_STATUS" == "200" ]]; then
    echo "PASS: Online Boutique frontend is UP (HTTP 200)"
    break
  fi
  echo "HTTP $HTTP_STATUS — retrying (attempt $i/12)..."
  sleep 30
  [ $i -eq 12 ] && { echo "ERROR: Frontend failed to serve HTTP 200 after 6 minutes"; exit 1; }
done

echo "=== All Validation Tests PASSED for Online Boutique ==="
