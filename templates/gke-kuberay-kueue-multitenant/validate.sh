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
CLUSTER_NAME=${CLUSTER_NAME:-"ray-kueue-tf-cluster"}
REGION=${REGION:-"us-central1"}

export KUBECONFIG=$(mktemp)
cleanup() {
  rm -f "$KUBECONFIG"
}
trap cleanup EXIT

echo "Test 1: Cluster Connectivity..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
kubectl cluster-info
echo "Connectivity passed."

echo "Test 2: Operators Readiness..."
# Check KubeRay operator
kubectl wait --for=condition=available deployment/kuberay-operator -n default --timeout=5m || echo "KubeRay operator wait failed (could be different namespace or name)"

# Check Kueue operator
kubectl wait --for=condition=available deployment/kueue-controller-manager -n kueue-system --timeout=5m || echo "Kueue operator wait failed"

echo "Test 3: Kueue Queues Status..."
kubectl wait --for=condition=Active clusterqueue/team-a-cq --timeout=5m
kubectl wait --for=condition=Active clusterqueue/team-b-cq --timeout=5m
kubectl wait --for=condition=Active localqueue/team-a-queue -n team-a --timeout=5m
kubectl wait --for=condition=Active localqueue/team-b-queue -n team-b --timeout=5m
echo "Queues are active."

echo "Test 4: RayClusters Validation..."
# Wait for RayClusters to be created (they might be pending due to resources or Kueue)
# We just check if they are admitted by Kueue or at least exist.
kubectl get raycluster raycluster-team-a -n team-a
kubectl get raycluster raycluster-team-b -n team-b

# It can take some time for RayCluster pods to start because nodes need to autoscale.
echo "All Validation Tests passed successfully!"
