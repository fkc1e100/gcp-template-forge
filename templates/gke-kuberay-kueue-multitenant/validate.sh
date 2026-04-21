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

# 1.5 Apply Workload in stages to avoid webhook race conditions
WORKLOAD_DIR="$(dirname "$0")/config-connector-workload"
if [ -d "$WORKLOAD_DIR" ]; then
  echo "Applying CRDs and Operators from $WORKLOAD_DIR..."
  # We use --server-side apply to handle large CRDs (e.g. KubeRay) that exceed the annotation limit.
  kubectl apply --server-side -f "$WORKLOAD_DIR/00-kuberay-operator-crds.yaml"
  kubectl apply --server-side -f "$WORKLOAD_DIR/00-kueue-operator-crds.yaml"
  
  echo "Waiting for CRDs to be established..."
  kubectl wait --for=condition=Established crd/rayclusters.ray.io --timeout=5m || debug_failure "RayCluster CRD not established"
  kubectl wait --for=condition=Established crd/clusterqueues.kueue.x-k8s.io --timeout=5m || debug_failure "ClusterQueue CRD not established"

  kubectl apply --server-side -f "$WORKLOAD_DIR/01-namespaces.yaml"

  # Check if operators are already installed (TF path)
  if kubectl get deployment kuberay-operator -n default >/dev/null 2>&1 && \
     kubectl get deployment kueue-controller-manager -n kueue-system >/dev/null 2>&1; then
    echo "Operators already present, skipping redundant application."
  else
    echo "Applying Operators from $WORKLOAD_DIR..."
    kubectl apply --server-side -f "$WORKLOAD_DIR/01-kuberay-operator.yaml"
    kubectl apply --server-side -f "$WORKLOAD_DIR/01-kueue-operator.yaml"
  fi

  # 2. Operator Readiness
  echo "Test 2: Operator Readiness..."
  echo "Checking KubeRay Operator..."
  kubectl wait --for=condition=available deployment/kuberay-operator -n default --timeout=15m || debug_failure "KubeRay Operator failed to become ready"

  echo "Checking Kueue Operator..."
  kubectl wait --for=condition=available deployment/kueue-controller-manager -n kueue-system --timeout=15m || debug_failure "Kueue Operator failed to become ready"
  echo "Operators are ready."

  # 2.5 Apply Custom Resources (with retries for webhook readiness)
  echo "Applying Custom Resources..."
  applied=false
  for i in {1..6}; do
    if kubectl apply --server-side -f "$WORKLOAD_DIR/02-kueue-config.yaml" && \
       kubectl apply --server-side -f "$WORKLOAD_DIR/03-ray-clusters.yaml"; then
      applied=true
      break
    fi
    echo "Wait for webhooks to be ready (attempt $i/6)..."
    sleep 20
  done
  if [ "$applied" = false ]; then
    debug_failure "Failed to apply custom resources after several attempts (webhook race condition)"
  fi

  echo "Installing NVIDIA GPU Drivers..."
  kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded-latest.yaml
  
  echo "Waiting for GPU nodes to become ready (with GPU capacity)..."
  echo "Note: This may take several minutes as the autoscaler provisions GPU nodes for the RayClusters."
  for i in {1..30}; do
    if kubectl get nodes -o jsonpath='{.items[*].status.capacity}' | grep -q "nvidia.com/gpu"; then
      echo "GPU capacity detected on nodes."
      break
    fi
    echo "Waiting for GPU capacity (attempt $i/30)..."
    sleep 30
    if [ $i -eq 30 ]; then
      echo "Warning: GPU capacity not detected on nodes after 15 minutes. RayClusters may fail to start."
    fi
  done
else
  echo "Warning: config-connector-workload directory not found at $WORKLOAD_DIR"
  echo "Checking Operator Readiness (expecting Helm install)..."
  kubectl wait --for=condition=available deployment/kuberay-operator -n default --timeout=15m || debug_failure "KubeRay Operator (Helm) failed to become ready"
  kubectl wait --for=condition=available deployment/kueue-controller-manager -n kueue-system --timeout=15m || debug_failure "Kueue Operator (Helm) failed to become ready"
  
  # Even if WORKLOAD_DIR is missing, we still need to apply the resources in TF path
  # Wait, in TF path, the directory IS present because it's part of the repo.
fi

# 3. Kueue Resource Readiness
echo "Test 3: Kueue Resource Readiness..."
for i in {1..12}; do
  if kubectl get clusterqueue team-a-cq && \
     kubectl get clusterqueue team-b-cq && \
     kubectl get localqueue team-a-lq -n team-a && \
     kubectl get localqueue team-b-lq -n team-b; then
    echo "Kueue resources are present."
    break
  fi
  echo "Waiting for Kueue resources (attempt $i/12)..."
  sleep 10
  if [ $i -eq 12 ]; then
    debug_failure "Kueue resources failed to become present"
  fi
done

# 4. RayCluster Readiness
echo "Test 4: RayCluster Readiness..."
set +e
kubectl wait --for=jsonpath='{.status.state}'=ready raycluster/raycluster-team-a -n team-a --timeout=25m
RESULT_A=$?
kubectl wait --for=jsonpath='{.status.state}'=ready raycluster/raycluster-team-b -n team-b --timeout=25m
RESULT_B=$?
set -e

if [ $RESULT_A -ne 0 ] || [ $RESULT_B -ne 0 ]; then
  debug_failure "RayClusters failed to become ready"
fi
echo "RayClusters are ready."

echo "All Validation Tests passed successfully!"
