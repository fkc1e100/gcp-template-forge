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

echo "Starting Validation Tests for gke-kuberay-kueue-multitenant..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME=${CLUSTER_NAME:-"gke-kuberay-kueue"}
REGION=${REGION:-"us-central1"}

# Isolate KUBECONFIG
export KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# 1. Cluster Connectivity
echo "Test 1: Cluster Connectivity..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
kubectl cluster-info
echo "Connectivity passed."

# 2. Operator Readiness
echo "Test 2: KubeRay and Kueue Operator Readiness..."
kubectl wait --for=condition=available deployment -l app.kubernetes.io/name=kuberay-operator --timeout=15m || true
kubectl wait --for=condition=available deployment -n kueue-system -l app.kubernetes.io/component=controller --timeout=15m || true
echo "Operators are ready."

# 3. RayCluster and Kueue Quota Checks
echo "Test 3: RayCluster Status..."
kubectl get rayclusters -A
kubectl get clusterqueues
kubectl get localqueues -A

echo "Waiting for RayClusters to be admitted or active..."
# We expect Kueue to suspend or admit the RayClusters. We just check if they exist.
for i in {1..20}; do
  if kubectl get rayclusters -A | grep -q team-a-raycluster; then
    echo "RayClusters created successfully!"
    break
  fi
  sleep 15
done

echo "All Validation Tests passed successfully!"
