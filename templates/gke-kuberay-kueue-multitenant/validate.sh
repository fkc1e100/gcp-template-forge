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
CLUSTER_NAME=${CLUSTER_NAME:-"gke-kuberay-kueue-multitenant"}
REGION=${REGION:-"us-central1"}

# Isolate KUBECONFIG
export KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# Helper for debugging failures
debug_failure() {
  local msg=$1
  echo "Error: $msg"
  echo "=== Debug Info: Nodes ==="
  kubectl get nodes
  echo "=== Debug Info: Pods (kueue-system) ==="
  kubectl get pods -n kueue-system
  echo "=== Debug Info: Pods (default) ==="
  kubectl get pods -n default
  echo "=== Debug Info: Events (all) ==="
  kubectl get events -A --sort-by='.lastTimestamp' | tail -n 50
  echo "=== Debug Info: Kueue Operator Logs ==="
  kubectl logs -l control-plane=controller-manager -n kueue-system --all-containers --tail=100 || echo "Could not fetch Kueue logs"
  exit 1
}

# 1. Cluster Connectivity
echo "Test 1: Cluster Connectivity..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
kubectl cluster-info || debug_failure "Failed to connect to cluster"
echo "Connectivity passed."

# 2. Operator Readiness
echo "Test 2: Operator Readiness..."
echo "Waiting for CRDs to be established..."
# These CRDs should have been installed by Helm or manually applied from config-connector-workload
kubectl wait --for=condition=Established crd/rayclusters.ray.io --timeout=5m || debug_failure "RayCluster CRD not established"
kubectl wait --for=condition=Established crd/clusterqueues.kueue.x-k8s.io --timeout=5m || debug_failure "ClusterQueue CRD not established"

echo "Checking KubeRay Operator..."
kubectl wait --for=condition=available deployment/kuberay-operator -n default --timeout=15m || debug_failure "KubeRay Operator failed to become ready"

echo "Checking Kueue Operator..."
kubectl wait --for=condition=available deployment/kueue-controller-manager -n kueue-system --timeout=15m || debug_failure "Kueue Operator failed to become ready"
echo "Operators are ready."

# 3. Kueue Resource Readiness
echo "Test 3: Kueue Resource Readiness..."
# Resources should have been installed by Helm or config-connector-workload
echo "Waiting for Kueue resources..."
for i in {1..30}; do
  if kubectl get clusterqueue team-a-cq && \
     kubectl get clusterqueue team-b-cq && \
     kubectl get localqueue team-a-lq -n team-a && \
     kubectl get localqueue team-b-lq -n team-b; then
    echo "Kueue resources are present."
    break
  fi
  echo "Waiting for Kueue resources (attempt $i/30)..."
  sleep 10
  if [ $i -eq 30 ]; then
    debug_failure "Kueue resources failed to become present"
  fi
done

# 4. RayCluster Readiness
echo "Test 4: RayCluster Readiness..."
# These should have been installed by Helm or config-connector-workload
echo "Waiting for RayClusters to become ready..."
echo "Note: This triggers autoscaling for GPU nodes, which can take several minutes."

# Verify GPU Driver installer is present
kubectl get daemonset nvidia-driver-installer -n kube-system || echo "Warning: nvidia-driver-installer not found yet."

set +e
kubectl wait --for=jsonpath='{.status.state}'=ready raycluster/raycluster-team-a -n team-a --timeout=25m
RESULT_A=$?
kubectl wait --for=jsonpath='{.status.state}'=ready raycluster/raycluster-team-b -n team-b --timeout=25m
RESULT_B=$?
set -e

if [ $RESULT_A -ne 0 ] || [ $RESULT_B -ne 0 ]; then
  debug_failure "RayClusters failed to become ready"
fi

# 5. Resource isolation verification
echo "Test 5: Resource Isolation Verification..."
kubectl get resourcequota team-a-quota -n team-a || debug_failure "ResourceQuota for team-a not found"
kubectl get limitrange team-a-limits -n team-a || debug_failure "LimitRange for team-a not found"
echo "Resource isolation is configured."

echo "All Validation Tests passed successfully!"
