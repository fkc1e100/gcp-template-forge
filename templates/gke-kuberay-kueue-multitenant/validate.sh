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

echo "Starting Validation Tests for ray-kueue-multi..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME=${CLUSTER_NAME:-"ray-kueue-multi-cluster"}
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
echo "Test 2: Operator Readiness..."
kubectl wait --for=condition=available deployment/kuberay-operator -n kuberay-system --timeout=10m
kubectl wait --for=condition=available deployment/kueue-controller-manager -n kueue-system --timeout=10m
echo "Operators are ready."

# 3. Kueue Configuration Readiness
echo "Test 3: Kueue Configuration..."
kubectl wait --for=condition=Active clusterqueue/cluster-queue --timeout=5m
echo "Kueue ClusterQueue is active."

# 4. RayCluster Readiness (Team A)
echo "Test 4: RayCluster Readiness (Team A)..."
# The head pod should be admitted and start
kubectl wait --for=condition=Ready pod -l ray.io/node-type=head -n team-a --timeout=15m
echo "Team A Ray head is ready."

# 5. Equitable Sharing Verification
echo "Test 5: Verification of Kueue Admittance..."
# Check if Team A worker is admitted
kubectl wait --for=condition=Ready pod -l ray.io/node-type=worker -n team-a --timeout=15m
echo "Team A Ray worker is ready."

# Check if Team B worker is admitted (Total GPU quota is 2, and we have 2 workers)
kubectl wait --for=condition=Ready pod -l ray.io/node-type=worker -n team-b --timeout=15m
echo "Team B Ray worker is ready."

echo "All Validation Tests passed successfully!"
