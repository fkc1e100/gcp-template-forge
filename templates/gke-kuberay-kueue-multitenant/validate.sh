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

echo "Starting Validation Tests for gke-ray-kueue-multi..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME=${CLUSTER_NAME:-"gke-ray-kueue-multi"}
REGION=${REGION:-"us-central1"}

# Isolate KUBECONFIG
export KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# 1. Cluster Connectivity
echo "Test 1: Cluster Connectivity..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
kubectl cluster-info
echo "Connectivity passed."

# 2. Install Kueue (if not already present)
if ! kubectl get deployment kueue-controller-manager -n kueue-system >/dev/null 2>&1; then
    echo "Installing Kueue Operator..."
    kubectl apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/v0.8.2/manifests.yaml
    kubectl wait --for=condition=available deployment kueue-controller-manager -n kueue-system --timeout=5m
fi
echo "Kueue is ready."

# 3. Wait for Ray Operator (Add-on)
echo "Waiting for Ray Operator..."
kubectl wait --for=condition=available deployment ray-operator -n ray-system --timeout=5m
echo "Ray Operator is ready."

# 4. Deploy Workload (if not already deployed by CI)
if ! kubectl get raycluster ray-team-a -n team-a >/dev/null 2>&1; then
    echo "Deploying Ray Workload..."
    helm upgrade --install release ./terraform-helm/workload --wait --timeout=10m
fi

# 5. Verify Kueue Resources
echo "Verifying Kueue resources..."
kubectl get clusterqueue
kubectl get resourceflavor default-flavor
kubectl get localqueue -n team-a
kubectl get localqueue -n team-b

# 6. Verify Ray Clusters and Pods
echo "Verifying Ray clusters and pods..."
# RayCluster might take a bit to create pods
for i in {1..10}; do
    PODS_A=$(kubectl get pods -n team-a -l ray.io/cluster=ray-team-a --no-headers | wc -l)
    PODS_B=$(kubectl get pods -n team-b -l ray.io/cluster=ray-team-b --no-headers | wc -l)
    echo "Team A pods: $PODS_A, Team B pods: $PODS_B"
    if [ "$PODS_A" -gt 0 ] && [ "$PODS_B" -gt 0 ]; then
        break
    fi
    sleep 30
done

# Wait for Ray pods to be scheduled (via Kueue)
kubectl wait --for=condition=Ready pod -n team-a -l ray.io/node-type=head --timeout=5m
kubectl wait --for=condition=Ready pod -n team-b -l ray.io/node-type=head --timeout=5m

echo "All Validation Tests passed successfully!"
