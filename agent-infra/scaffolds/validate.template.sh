#!/usr/bin/env bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# validate.sh scaffold — copy to your template and complete ALL sections.
#
# CRITICAL: This script must PROVE the workload works end-to-end.
# "Deployment Available" is NOT sufficient. You MUST add at least one of:
#   - curl/wget to an HTTP endpoint and verify a non-empty/200 response
#   - kubectl exec into a pod and run a meaningful command (psql, redis-cli, etc.)
#   - A custom resource status check (RayCluster Ready, LocalQueue Active, etc.)
#
# CI will run this script after deploying the template. If it exits 0 without
# actually verifying the workload, the template is considered broken.
#
# PLACEHOLDERS to replace:
#   {{TEMPLATE_NAME}}  — human-readable name, e.g. "GKE KubeRay + Kueue"
#   {{SHORT_NAME}}     — shortName from template.yaml, e.g. "gke-kuberay-kueue"
#   {{APP_LABEL}}      — label selector for your workload, e.g. "app.kubernetes.io/name=ray-head"
#   {{NAMESPACE}}      — workload namespace, e.g. "ray-system"

set -euo pipefail

echo "=== Validation: {{TEMPLATE_NAME}} ==="

PROJECT_ID="${PROJECT_ID:-gca-gke-2025}"
CLUSTER_NAME="${CLUSTER_NAME:-{{SHORT_NAME}}-tf}"
REGION="${REGION:-us-central1}"
NAMESPACE="${NAMESPACE:-{{NAMESPACE}}}"

# Isolate kubeconfig — never pollute the runner's default context
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
# Replace {{APP_LABEL}} with the label your Deployment/StatefulSet uses.
# Use a label that works for BOTH the Helm path and the KCC path.
echo "--- Test 3: Workload Deployment Readiness ---"
kubectl wait deployment \
  -l "{{APP_LABEL}}" \
  -n "${NAMESPACE}" \
  --for=condition=available \
  --timeout=30m
kubectl get pods -n "${NAMESPACE}" -l "{{APP_LABEL}}" -o wide
echo "PASS: Workload Deployment is Available."

# ── 4. Pod Log Sanity Check ───────────────────────────────────────────────────
# Verify the workload started cleanly — no crash-loops hiding in "Available".
echo "--- Test 4: Pod Log Sanity ---"
POD=$(kubectl get pod -n "${NAMESPACE}" -l "{{APP_LABEL}}" \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -z "$POD" ]; then
  echo "ERROR: No Running pod found matching label {{APP_LABEL}} in namespace ${NAMESPACE}"
  kubectl get events -n "${NAMESPACE}" --sort-by='.lastTimestamp' | tail -20
  exit 1
fi
echo "Checking logs for pod $POD (last 20 lines)..."
kubectl logs "$POD" -n "${NAMESPACE}" --tail=20
echo "PASS: Pod is running and producing logs."

# ── 5. Workload Functional Verification ──────────────────────────────────────
# THIS SECTION IS MANDATORY — pick the pattern that matches your workload.
# Remove the patterns that don't apply. Leaving this section empty = CI failure.
echo "--- Test 5: Workload Functional Verification ---"

# ── PATTERN A: HTTP Service (LoadBalancer or Gateway) ────────────────────────
# Use this for any workload that exposes an HTTP/HTTPS endpoint.
#
# SERVICE_IP=""
# for i in $(seq 1 20); do
#   SERVICE_IP=$(kubectl get svc -n "${NAMESPACE}" -l "{{APP_LABEL}}" \
#     -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
#   [ -n "$SERVICE_IP" ] && break
#   echo "Waiting for LoadBalancer IP (attempt $i/20)..."
#   sleep 30
# done
# if [ -z "$SERVICE_IP" ]; then
#   echo "ERROR: LoadBalancer IP not assigned after 10 minutes"
#   kubectl get svc -n "${NAMESPACE}"
#   exit 1
# fi
# echo "LoadBalancer IP: ${SERVICE_IP}"
# for i in $(seq 1 12); do
#   HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
#     --connect-timeout 5 --max-time 15 "http://${SERVICE_IP}:80/" || echo "000")
#   if [[ "$HTTP_STATUS" =~ ^(200|201|204|301|302)$ ]]; then
#     echo "PASS: Endpoint http://${SERVICE_IP}:80/ returned HTTP $HTTP_STATUS"
#     break
#   fi
#   echo "HTTP $HTTP_STATUS — retrying (attempt $i/12)..."
#   sleep 30
#   [ $i -eq 12 ] && { echo "ERROR: Endpoint failed after 12 attempts"; exit 1; }
# done

# ── PATTERN B: exec-based check (DB, cache, queue) ───────────────────────────
# Use this for Cloud SQL, Redis, Kafka, Spanner client, etc.
#
# kubectl exec -n "${NAMESPACE}" "$POD" -- \
#   psql -h localhost -U app -c "SELECT 1" > /dev/null \
#   && echo "PASS: Database is accepting connections."
#
# kubectl exec -n "${NAMESPACE}" "$POD" -- \
#   redis-cli ping | grep -q PONG \
#   && echo "PASS: Redis is responding."

# ── PATTERN C: Custom resource status (KubeRay, Kueue, etc.) ─────────────────
# Use this for templates that deploy CRD-backed resources.
#
# kubectl wait raycluster --all -n "${NAMESPACE}" \
#   --for=condition=Ready --timeout=20m \
#   && echo "PASS: RayCluster is Ready."
#
# kubectl wait localqueue --all -n "${NAMESPACE}" \
#   --for=condition=Active --timeout=5m \
#   && echo "PASS: LocalQueue is Active."
#
# Submit a test job and verify completion:
# kubectl create -f - <<JOB_EOF
# apiVersion: batch/v1
# kind: Job
# metadata:
#   name: validate-test-$(date +%s)
#   namespace: ${NAMESPACE}
# spec:
#   template:
#     spec:
#       restartPolicy: Never
#       containers:
#       - name: test
#         image: gcr.io/google-containers/busybox
#         command: ["sh", "-c", "echo 'workload verification ok'"]
# JOB_EOF
# kubectl wait job -l app=validate-test -n "${NAMESPACE}" \
#   --for=condition=Complete --timeout=10m \
#   && echo "PASS: Test job completed."

# ── TODO: IMPLEMENT ONE OF THE PATTERNS ABOVE ────────────────────────────────
# Do NOT leave this section empty. A validate.sh that only reaches this line
# without actually verifying the workload is a broken validate.sh.
echo "ERROR: validate.sh is incomplete — Test 5 (Workload Functional Verification) not implemented."
echo "Copy one of the patterns above and adapt it to this template's workload."
exit 1
# ── END FUNCTIONAL VERIFICATION ──────────────────────────────────────────────

echo "=== All Validation Tests PASSED for {{TEMPLATE_NAME}} ==="
