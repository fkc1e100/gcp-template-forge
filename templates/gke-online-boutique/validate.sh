#!/usr/bin/env bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

echo "=== Validation: Online Boutique Microservices Demo ==="

PROJECT_ID="${PROJECT_ID:-gca-gke-2025}"
CLUSTER_NAME="${CLUSTER_NAME:-online-boutique-gke-tf}"
REGION="${REGION:-us-central1}"
NAMESPACE="${NAMESPACE:-default}"

# Isolate kubeconfig — never pollute the runner's default context
export KUBECONFIG
KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# ── 1. Cluster Connectivity ───────────────────────────────────────────────────
echo "--- Test 1: Cluster Connectivity ---"
gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${REGION}" --project "${PROJECT_ID}"
kubectl cluster-info
kubectl get nodes -o wide
echo "PASS: Cluster is reachable."

# ── 2. Node Readiness ─────────────────────────────────────────────────────────
echo "--- Test 2: Node Readiness ---"
kubectl wait nodes --all --for=condition=Ready --timeout=10m
echo "PASS: All nodes are Ready."

# ── 3. Workload Deployment Readiness ─────────────────────────────────────────
echo "--- Test 3: Workload Deployment Readiness ---"
kubectl wait deployment -l "app=frontend" -n "${NAMESPACE}" --for=condition=available --timeout=30m
kubectl get pods -n "${NAMESPACE}" -l "app=frontend" -o wide
echo "PASS: Workload Deployment is Available."

# ── 4. Pod Log Sanity Check ───────────────────────────────────────────────────
echo "--- Test 4: Pod Log Sanity ---"
POD=$(kubectl get pod -n "${NAMESPACE}" -l "app=frontend" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -z "$POD" ]; then
  echo "ERROR: No Running pod found matching label app=frontend in namespace ${NAMESPACE}"
  kubectl get events -n "${NAMESPACE}" --sort-by='.lastTimestamp' | tail -20
  exit 1
fi
echo "Checking logs for pod $POD (last 20 lines)..."
kubectl logs "$POD" -n "${NAMESPACE}" --tail=20
echo "PASS: Pod is running and producing logs."

# ── 5. Workload Functional Verification ──────────────────────────────────────
echo "--- Test 5: Workload Functional Verification ---"

SERVICE_IP=""
for i in $(seq 1 30); do
  SERVICE_IP=$(kubectl get svc -n "${NAMESPACE}" frontend-external 
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  [ -n "$SERVICE_IP" ] && break
  echo "Waiting for LoadBalancer IP (attempt $i/30)..."
  sleep 10
done

if [ -z "$SERVICE_IP" ]; then
  echo "ERROR: LoadBalancer IP for frontend-external not assigned after 5 minutes"
  kubectl get svc -n "${NAMESPACE}"
  exit 1
fi

echo "LoadBalancer IP: ${SERVICE_IP}"

for i in $(seq 1 15); do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 15 "http://${SERVICE_IP}:80/" || echo "000")
  if [[ "$HTTP_STATUS" =~ ^(200|201|204|301|302)$ ]]; then
    echo "PASS: Endpoint http://${SERVICE_IP}:80/ returned HTTP $HTTP_STATUS"
    break
  fi
  echo "HTTP $HTTP_STATUS — retrying (attempt $i/15)..."
  sleep 10
  [ $i -eq 15 ] && { echo "ERROR: Endpoint failed after 15 attempts"; exit 1; }
done

echo "=== All Validation Tests PASSED for Online Boutique Microservices Demo ==="
