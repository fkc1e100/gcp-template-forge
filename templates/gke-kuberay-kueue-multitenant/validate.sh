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
CLUSTER_NAME=${CLUSTER_NAME:-"kuberay-kueue-cluster"}
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
echo "Checking KubeRay Operator..."
kubectl wait --for=condition=available deployment/kuberay-operator -n default --timeout=10m

echo "Checking Kueue Operator..."
# Kueue name can vary if installed via manifests or helm, 
# in my manifests it's usually 'kueue-controller-manager' in 'kueue-system'
kubectl wait --for=condition=available deployment/kueue-controller-manager -n kueue-system --timeout=10m
echo "Operators are ready."

# 3. Kueue Resource Readiness
echo "Test 3: Kueue Resource Readiness..."
kubectl get clusterqueue team-a-cq
kubectl get clusterqueue team-b-cq
kubectl get localqueue team-a-lq -n team-a
kubectl get localqueue team-b-lq -n team-b
echo "Kueue resources are present."

# 4. RayCluster Readiness
echo "Test 4: RayCluster Readiness..."
# RayClusters take time to provision head pods
kubectl wait --for=jsonpath='{.status.state}'=ready raycluster/raycluster-team-a -n team-a --timeout=10m
kubectl wait --for=jsonpath='{.status.state}'=ready raycluster/raycluster-team-b -n team-b --timeout=10m
echo "RayClusters are ready."

echo "All Validation Tests passed successfully!"
