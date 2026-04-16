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

echo "Starting Latest GKE Features Validation Tests..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME=${CLUSTER_NAME:-"latest-gke-features-tf"}
REGION=${REGION:-"us-central1"}
NAMESPACE=${NAMESPACE:-"default"}

# Isolate KUBECONFIG
export KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# 1. Cluster Connectivity
echo "Test 1: Cluster Connectivity..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
kubectl cluster-info
echo "Connectivity passed."

# 2. Workload Readiness
echo "Test 2: Workload Readiness..."
# Deployment name from fullname helper: <release-name>-<chart-name>
# In CI, release name is 'release', chart name is 'latest-features-workload'
kubectl wait --for=condition=available deployment/release-latest-features-workload -n ${NAMESPACE} --timeout=10m
echo "Workload is available."

# 3. Native Sidecar Validation
echo "Test 3: Native Sidecar Validation..."
POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=latest-features-workload -o jsonpath='{.items[0].metadata.name}')
RESTART_POLICY=$(kubectl get pod ${POD_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.initContainers[0].restartPolicy}')
if [ "$RESTART_POLICY" != "Always" ]; then
  echo "Native Sidecar check failed! restartPolicy is $RESTART_POLICY, expected Always."
  exit 1
fi
echo "Native Sidecar validated (restartPolicy: Always found)."

# 4. Gateway API Validation
echo "Test 4: Gateway API Validation..."
# Check if Gateway is programmed
kubectl wait --for=condition=Programmed gateway/latest-features-gateway -n ${NAMESPACE} --timeout=15m

# Get Gateway IP
GATEWAY_IP=$(kubectl get gateway latest-features-gateway -n ${NAMESPACE} -o jsonpath='{.status.addresses[0].value}')
echo "Gateway IP: ${GATEWAY_IP}"

if [ -z "$GATEWAY_IP" ]; then
  echo "Failed to get Gateway IP!"
  exit 1
fi

echo "Testing endpoint http://${GATEWAY_IP}/..."
# Retry curl as the LB might take a few moments to actually start serving
for i in {1..12}; do
  if curl -sf --connect-timeout 5 --max-time 10 http://${GATEWAY_IP}/; then
    echo "Gateway endpoint test passed!"
    break
  fi
  echo "Gateway endpoint not ready (attempt $i/12)..."
  sleep 30
  if [ $i -eq 12 ]; then
    echo "Gateway endpoint test failed after 12 attempts!"
    exit 1
  fi
done

# 5. Image Streaming Check
echo "Test 5: Image Streaming Check..."
# Verify GCFS is enabled on the node pool
# Use the dynamic pool name (in TF it is ${CLUSTER_NAME}-pool)
NODE_POOL_NAME="${CLUSTER_NAME}-pool"
GCFS_ENABLED=$(gcloud container node-pools describe ${NODE_POOL_NAME} --cluster ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID} --format="value(config.gcfsConfig.enabled)")
if [ "$GCFS_ENABLED" != "True" ]; then
  echo "Image Streaming (GCFS) check failed! Enabled: $GCFS_ENABLED"
  exit 1
fi
echo "Image Streaming (GCFS) validated."

echo "All Latest GKE Features Validation Tests passed successfully!"
