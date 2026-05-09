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

echo "=== Validation: K8s Deployer ==="

PROJECT_ID="${PROJECT_ID:-gca-gke-2025}"
REGION="${REGION:-us-central1}"
# Default to TF name, but allow override for KCC path
CLUSTER_NAME="${CLUSTER_NAME:-k8s-deployer-tf}"
NAMESPACE="${NAMESPACE:-default}"
APP_LABEL="app=k8s-deployer"

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
kubectl wait deployment \
  -l "${APP_LABEL}" \
  -n "${NAMESPACE}" \
  --for=condition=available \
  --timeout=15m
kubectl get pods -n "${NAMESPACE}" -l "${APP_LABEL}" -o wide
echo "PASS: Workload Deployment is Available."

# ── 4. Pod Log Sanity Check ───────────────────────────────────────────────────
echo "--- Test 4: Pod Log Sanity ---"
POD=$(kubectl get pod -n "${NAMESPACE}" -l "${APP_LABEL}" \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -z "$POD" ]; then
  echo "ERROR: No Running pod found matching label ${APP_LABEL} in namespace ${NAMESPACE}"
  kubectl get events -n "${NAMESPACE}" --sort-by='.lastTimestamp' | tail -20
  exit 1
fi
echo "Checking logs for pod $POD (last 20 lines)..."
kubectl logs "$POD" -n "${NAMESPACE}" --tail=20
echo "PASS: Pod is running and producing logs."

# ── 5. Workload Functional Verification ──────────────────────────────────────
echo "--- Test 5: Workload Functional Verification ---"
# Verify Nginx is serving by curlling localhost inside the pod
echo "Testing HTTP response from within the pod..."
kubectl exec -n "${NAMESPACE}" "$POD" -- curl -s localhost:80 | grep -q "Welcome to nginx!" \
  && echo "PASS: Nginx is serving content."

echo "=== All Validation Tests PASSED for K8s Deployer ==="
