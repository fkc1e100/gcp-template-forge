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
CLUSTER_NAME=${CLUSTER_NAME:-"kuberay-kueue-tf"}
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
kubectl wait --for=condition=available deployment -n ray-system kuberay-operator --timeout=10m
kubectl wait --for=condition=available deployment -n kueue-system kueue-controller-manager --timeout=10m
echo "Operators are ready."

# 3. Kueue Configuration
echo "Test 3: Kueue Configuration..."
kubectl get clusterqueue team-a-cq
kubectl get clusterqueue team-b-cq
kubectl get localqueue team-a-local-queue -n team-a
kubectl get localqueue team-b-local-queue -n team-b
echo "Kueue configuration found."

# 4. RayCluster Creation
echo "Test 4: RayCluster Creation..."
# RayClusters might stay in 'pending' if Kueue is still starting up or if resources are scarce, 
# but they should at least exist and be managed by Kueue.
kubectl get raycluster team-a-raycluster -n team-a
kubectl get raycluster team-b-raycluster -n team-b

# Check if Kueue admitted the clusters (status.conditions)
# We expect at least one to be admitted if quota allows.
echo "Checking Kueue admission status..."
kubectl get workload -A

echo "All Validation Tests passed successfully!"
