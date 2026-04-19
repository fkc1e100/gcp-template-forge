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

set -e

echo "Starting Validation Tests for basic-gke-hello-world..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME=${CLUSTER_NAME:-"basic-gke-hello-world"}
REGION=${REGION:-"us-central1"}
NAMESPACE_WORKLOAD=${NAMESPACE_WORKLOAD:-"default"}

# Isolate KUBECONFIG
export KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# 1. Cluster Connectivity
echo "Test 1: Cluster Connectivity..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
kubectl cluster-info
echo "Connectivity passed."

# 1.5 Apply KCC Workload (if on KCC cluster)
# Detect KCC cluster by checking if name does NOT end in -tf
# We use the directory of the script to find the workload manifest
if [[ ! "$CLUSTER_NAME" =~ -tf$ ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  WORKLOAD_MANIFEST="${SCRIPT_DIR}/config-connector-workload/workload.yaml"
  if [ -f "$WORKLOAD_MANIFEST" ]; then
    echo "KCC cluster detected. Applying KCC workload manifests from $WORKLOAD_MANIFEST..."
    kubectl apply -f "$WORKLOAD_MANIFEST" -n ${NAMESPACE_WORKLOAD}
  else
    echo "Warning: Workload manifest $WORKLOAD_MANIFEST not found."
  fi
fi

# 2. Workload Readiness
echo "Test 2: Workload Readiness..."
# Wait for any deployment with the correct app label
# Increased to 30m to comply with project mandates
kubectl wait --for=condition=Available deployment -l app.kubernetes.io/name=hello-world -n ${NAMESPACE_WORKLOAD} --timeout=30m
echo "Workload is available."

# 3. Endpoint Interaction
echo "Test 3: Endpoint Interaction..."
# Wait for LoadBalancer IP
# Increased to 60 attempts (30 minutes) to comply with project mandates
SERVICE_IP=""
for i in {1..60}; do
  SERVICE_IP=$(kubectl get svc -n ${NAMESPACE_WORKLOAD} -l app.kubernetes.io/name=hello-world -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' || true)
  if [ ! -z "$SERVICE_IP" ]; then
    break
  fi
  echo "Waiting for LoadBalancer IP (attempt $i/60)..."
  sleep 30
done

if [ -z "$SERVICE_IP" ]; then
  echo "Failed to get LoadBalancer IP!"
  exit 1
fi

echo "Testing endpoint http://${SERVICE_IP}:80/..."
# Retry curl as the LB might take a few moments to actually start serving
# Increased to 60 attempts (30 minutes) to avoid flakes
for i in {1..60}; do
  if curl -sf --connect-timeout 5 --max-time 10 http://${SERVICE_IP}:80/; then
    echo "Endpoint test passed!"
    break
  fi
  echo "Endpoint not ready (attempt $i/60)..."
  sleep 30
  if [ $i -eq 60 ]; then
    echo "Endpoint test failed after 60 attempts!"
    exit 1
  fi
done

echo "All Validation Tests passed successfully!"
