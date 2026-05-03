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
#
# SCAFFOLD: Copy this file to your template as validate.sh and fill in the
# TEMPLATE-SPECIFIC CHECKS section. Keep the base checks — they verify that
# the cluster is healthy and the workload is Running before your app checks.

set -e

echo "Starting Validation Tests for {{TEMPLATE_NAME}}..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME=${CLUSTER_NAME:-"{{SHORT_NAME}}-tf"}
REGION=${REGION:-"us-central1"}
NAMESPACE_WORKLOAD=${NAMESPACE_WORKLOAD:-"default"}

# Isolate kubeconfig to avoid polluting the runner's default context.
export KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# ── 1. Cluster Connectivity ───────────────────────────────────────────────────
echo "Test 1: Cluster Connectivity..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --region "${REGION}" --project "${PROJECT_ID}"
kubectl cluster-info
kubectl get nodes
echo "Connectivity passed."

# ── 2. Node Readiness ─────────────────────────────────────────────────────────
echo "Test 2: Node Readiness..."
kubectl wait nodes --all --for=condition=Ready --timeout=10m
echo "All nodes are Ready."

# ── 3. Workload Readiness ─────────────────────────────────────────────────────
# SCAFFOLD: Replace the label selector with whatever labels your workload uses.
# The label selector approach is robust across both Helm and KCC deployment paths.
echo "Test 3: Workload Readiness..."
WORKLOAD_LABEL="${WORKLOAD_LABEL:-"app.kubernetes.io/name={{APP_NAME}}"}"
kubectl wait deployment \
  -l "${WORKLOAD_LABEL}" \
  -n "${NAMESPACE_WORKLOAD}" \
  --for=condition=available \
  --timeout=30m
echo "Workload is available."

# ── 4. Service Endpoint ───────────────────────────────────────────────────────
# SCAFFOLD: Uncomment and adapt if your template exposes a LoadBalancer/Gateway.
# If using Gateway API, replace 'svc' with 'gateway' and adjust jsonpath.
#
# echo "Test 4: Endpoint Interaction..."
# SERVICE_IP=""
# for i in {1..20}; do
#   SERVICE_IP=$(kubectl get svc -n "${NAMESPACE_WORKLOAD}" \
#     -l "${WORKLOAD_LABEL}" \
#     -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
#   [ -n "$SERVICE_IP" ] && break
#   echo "Waiting for LoadBalancer IP (attempt $i/20)..."
#   sleep 30
# done
# if [ -z "$SERVICE_IP" ]; then
#   echo "ERROR: Failed to obtain LoadBalancer IP after 10 minutes"
#   exit 1
# fi
# echo "Testing http://${SERVICE_IP}:80/ ..."
# for i in {1..12}; do
#   if curl -sf --connect-timeout 5 --max-time 10 "http://${SERVICE_IP}:80/"; then
#     echo "Endpoint test passed."
#     break
#   fi
#   echo "Endpoint not ready (attempt $i/12)..."
#   sleep 30
#   [ $i -eq 12 ] && { echo "ERROR: Endpoint failed after 12 attempts"; exit 1; }
# done

# ── TEMPLATE-SPECIFIC CHECKS ─────────────────────────────────────────────────
# Add checks specific to this template's workload. Examples:
#
# For KubeRay + Kueue:
#   kubectl wait raycluster --all -n ${NAMESPACE_WORKLOAD} --for=condition=Ready --timeout=15m
#   kubectl wait localqueue --all -n ${NAMESPACE_WORKLOAD} --for=condition=Active --timeout=5m
#
# For Cloud SQL workload:
#   kubectl exec -n ${NAMESPACE_WORKLOAD} deploy/app -- psql -c "SELECT 1" > /dev/null
#
# For AI inference (vLLM):
#   curl -sf http://${SERVICE_IP}:8000/health | grep -q "ok"
#
# TODO: Add template-specific validation here.

echo "All Validation Tests passed successfully for {{TEMPLATE_NAME}}!"
