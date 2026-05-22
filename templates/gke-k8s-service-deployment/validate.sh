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

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME=${CLUSTER_NAME:-"k8s-svc-lb-tf"}
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

# 2. Node Readiness
echo "Test 2: Node Readiness..."
kubectl wait nodes --all --for=condition=Ready --timeout=10m
echo "All nodes are Ready."

# 3. Workload Readiness
echo "Test 3: Workload Readiness..."
kubectl wait --for=condition=available deployment/web-service -n ${NAMESPACE_WORKLOAD} --timeout=30m
echo "Workload is available."

# 4. Endpoint Interaction
echo "Test 4: Endpoint Interaction..."
# Wait for LoadBalancer IP
SERVICE_IP=""
for i in {1..20}; do
  SERVICE_IP=$(kubectl get svc web-service-lb -n ${NAMESPACE_WORKLOAD} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || true)
  if [ ! -z "$SERVICE_IP" ]; then
    break
  fi
  echo "Waiting for LoadBalancer IP (attempt $i/20)..."
  sleep 30
done

if [ -z "$SERVICE_IP" ]; then
  echo "Failed to get LoadBalancer IP!"
  exit 1
fi

echo "Testing endpoint http://${SERVICE_IP}:80/..."
# Retry curl as the LB might take a few moments to actually start serving
for i in {1..12}; do
  if curl -sf --connect-timeout 5 --max-time 10 http://${SERVICE_IP}:80/; then
    echo "Endpoint test passed!"
    break
  fi
  echo "Endpoint not ready (attempt $i/12)..."
  sleep 30
  if [ $i -eq 12 ]; then
    echo "Endpoint test failed after 12 attempts!"
    exit 1
  fi
done

echo "All Validation Tests passed successfully for K8s Service Deployment!"
