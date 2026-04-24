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
  echo "=== Debug Info: Pods (all) ==="
  kubectl get pods -A
  echo "=== Debug Info: RayClusters (all) ==="
  kubectl get raycluster -A -o yaml || echo "Could not fetch RayClusters"
  echo "=== Debug Info: Kueue Workloads (all) ==="
  kubectl get workloads.kueue.x-k8s.io -A || echo "Could not fetch Kueue Workloads"
  echo "=== Debug Info: Events (all) ==="
  kubectl get events -A --sort-by='.lastTimestamp' | tail -n 100
  echo "=== Debug Info: Kueue Operator Logs ==="
  kubectl logs -l control-plane=controller-manager -n kueue-system --all-containers --tail=100 || echo "Could not fetch Kueue logs"
  echo "=== Debug Info: KubeRay Operator Logs ==="
  kubectl logs -l app.kubernetes.io/name=kuberay -n default --all-containers --tail=100 || echo "Could not fetch KubeRay logs"
  exit 1
}

# 1. Cluster Connectivity
echo "Test 1: Cluster Connectivity..."
# NOTE: This script strictly performs validation and readiness checks.
# Resource application is handled by the CI pipeline via Helm to avoid field ownership conflicts.
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
kubectl cluster-info || debug_failure "Failed to connect to cluster"
echo "Connectivity passed."

# 2. Operator Readiness
echo "Test 2: Operator Readiness..."
echo "Waiting for Operators to be available..."

echo "Checking KubeRay Operator..."
kubectl wait --for=condition=available deployment/kuberay-operator -n default --timeout=15m || debug_failure "KubeRay Operator failed to become ready"

echo "Checking Kueue Operator..."
kubectl wait --for=condition=available deployment/kueue-controller-manager -n kueue-system --timeout=15m || debug_failure "Kueue Operator failed to become ready"
echo "Operators are ready."

# 3. Custom Resource Verification
echo "Test 3: Verifying Custom Resources..."
echo "Waiting for CRDs to be established..."
# These CRDs should have been installed by Helm
kubectl wait --for=condition=Established crd/rayclusters.ray.io --timeout=5m || debug_failure "RayCluster CRD not established"
kubectl wait --for=condition=Established crd/clusterqueues.kueue.x-k8s.io --timeout=5m || debug_failure "ClusterQueue CRD not established"
echo "CRDs are established."

# 4. Kueue Resource Readiness
echo "Test 4: Kueue Resource Readiness..."
echo "Waiting for ClusterQueues to be active..."
kubectl wait --for=condition=Active clusterqueue/team-a-cq --timeout=5m || debug_failure "ClusterQueue team-a-cq failed to become active"
kubectl wait --for=condition=Active clusterqueue/team-b-cq --timeout=5m || debug_failure "ClusterQueue team-b-cq failed to become active"

echo "Checking for LocalQueues..."
kubectl get localqueue team-a-lq -n team-a || debug_failure "LocalQueue team-a-lq not found"
kubectl get localqueue team-b-lq -n team-b || debug_failure "LocalQueue team-b-lq not found"

echo "Kueue resources are ready."

# 5. RayCluster Readiness
echo "Test 5: RayCluster Readiness..."
# These should have been installed by Helm or config-connector-workload
echo "Waiting for RayClusters to become ready..."
echo "Note: This triggers autoscaling for GPU nodes, which can take several minutes."

# Verify GPU Driver installation is initiated via GKE annotation
kubectl get nodes -l cloud.google.com/gke-accelerator=nvidia-l4 -o jsonpath='{.items[*].metadata.labels.cloud\.google\.com/gke-gpu-driver-version}' | grep -q "DEFAULT" || echo "Warning: GPU nodes found but GKE driver version label not yet present."

wait_for_raycluster() {
  local name=$1
  local ns=$2
  local timeout=$3
  local start_time=$(date +%s)
  local end_time=$((start_time + timeout))

  echo "Monitoring RayCluster $name in namespace $ns..."
  while [ $(date +%s) -lt $end_time ]; do
    local state=$(kubectl get raycluster "$name" -n "$ns" -o jsonpath='{.status.state}' 2>/dev/null || echo "unknown")
    echo "Current state of $name: $state"
    if [[ "$state" == "ready" ]] || [[ "$state" == "Ready" ]]; then
      echo "RayCluster $name is ready!"
      return 0
    fi
    if [[ "$state" == "failed" ]] || [[ "$state" == "Failed" ]]; then
      echo "Error: RayCluster $name failed!"
      return 1
    fi
    sleep 30
  done
  echo "Timeout waiting for RayCluster $name"
  return 1
}

set +e
wait_for_raycluster "raycluster-team-a" "team-a" 2700 &
PID_A=$!

wait_for_raycluster "raycluster-team-b" "team-b" 2700 &
PID_B=$!

wait $PID_A
RESULT_A=$?
wait $PID_B
RESULT_B=$?
set -e

if [ $RESULT_A -ne 0 ] || [ $RESULT_B -ne 0 ]; then
  debug_failure "RayClusters failed to become ready"
fi

# 6. Resource isolation verification
echo "Test 6: Resource Isolation Verification..."
kubectl get limitrange team-a-limits -n team-a || debug_failure "LimitRange for team-a not found"
kubectl get networkpolicy ray-dashboard-restriction -n team-a || debug_failure "NetworkPolicy for team-a not found"
kubectl get networkpolicy ray-dashboard-restriction -n team-b || debug_failure "NetworkPolicy for team-b not found"
echo "Resource isolation is configured."

echo "All Validation Tests passed successfully!"
