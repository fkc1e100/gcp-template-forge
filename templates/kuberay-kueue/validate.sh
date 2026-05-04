#!/usr/bin/env bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# validate.sh for kuberay-kueue

set -euo pipefail

echo "=== Validation: Ray on GKE with Kueue ==="

PROJECT_ID="${PROJECT_ID:-gca-gke-2025}"
# Support both TF and KCC naming
CLUSTER_NAME="${CLUSTER_NAME:-kuberay-kueue-cluster}"
REGION="${REGION:-us-central1}"

# Isolate kubeconfig
export KUBECONFIG
KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# ── 1. Cluster Connectivity ───────────────────────────────────────────────────
echo "--- Test 1: Cluster Connectivity ---"
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --region "${REGION}" --project "${PROJECT_ID}"
kubectl cluster-info
echo "PASS: Cluster is reachable."

# ── 2. Node Readiness ─────────────────────────────────────────────────────────
echo "--- Test 2: Node Readiness ---"
kubectl wait nodes --all --for=condition=Ready --timeout=10m
echo "PASS: All nodes are Ready."

# ── 3. Operator Readiness ─────────────────────────────────────────────────────
echo "--- Test 3: Operator Readiness ---"
kubectl wait deployment -n kuberay-operator kuberay-operator --for=condition=available --timeout=5m
kubectl wait deployment -n kueue-system kueue-controller-manager --for=condition=available --timeout=5m
echo "PASS: Operators are Available."

# ── 4. Kueue Resource Readiness ───────────────────────────────────────────────
echo "--- Test 4: Kueue Resource Readiness ---"
# Wait for LocalQueues to be Active
kubectl wait localqueue team-a-queue -n team-a --for=condition=Active --timeout=2m
kubectl wait localqueue team-b-queue -n team-b --for=condition=Active --timeout=2m
echo "PASS: Kueue LocalQueues are Active."

# ── 5. Workload Functional Verification ──────────────────────────────────────
echo "--- Test 5: Workload Functional Verification ---"
# Wait for RayClusters to reach Ready state (this proves Ray operator is working)
echo "Waiting for RayClusters to be Ready (this may take time for GPU nodes)..."
kubectl wait raycluster team-a-raycluster -n team-a --for=condition=Ready --timeout=20m
kubectl wait raycluster team-b-raycluster -n team-b --for=condition=Ready --timeout=20m

# Verify Ray head pod is running
POD_A=$(kubectl get pod -n team-a -l ray.io/node-type=head -o jsonpath='{.items[0].metadata.name}')
echo "Checking logs for Ray head pod $POD_A..."
kubectl logs "$POD_A" -n team-a --tail=20

echo "PASS: RayClusters are Ready and pods are running."

echo "=== All Validation Tests PASSED for kuberay-kueue ==="
