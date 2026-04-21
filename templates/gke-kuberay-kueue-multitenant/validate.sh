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

# 1. Cluster Connectivity
echo "Test 1: Cluster Connectivity..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
kubectl cluster-info
echo "Connectivity passed."

# 1.5 Apply Workload in stages to avoid webhook race conditions
WORKLOAD_DIR="$(dirname "$0")/config-connector-workload"
if [ -d "$WORKLOAD_DIR" ]; then
  echo "Applying CRDs and Operators from $WORKLOAD_DIR..."
  # We use --server-side apply to handle large CRDs (e.g. KubeRay) that exceed the annotation limit.
  kubectl apply --server-side -f "$WORKLOAD_DIR/00-kuberay-operator-crds.yaml"
  kubectl apply --server-side -f "$WORKLOAD_DIR/00-kueue-operator-crds.yaml"
  
  echo "Waiting for CRDs to be established..."
  kubectl wait --for=condition=Established crd/rayclusters.ray.io --timeout=2m
  kubectl wait --for=condition=Established crd/clusterqueues.kueue.x-k8s.io --timeout=2m

  kubectl apply --server-side -f "$WORKLOAD_DIR/01-namespaces.yaml"
  kubectl apply --server-side -f "$WORKLOAD_DIR/01-kuberay-operator.yaml"
  kubectl apply --server-side -f "$WORKLOAD_DIR/01-kueue-operator.yaml"

  # 2. Operator Readiness (MUST be ready before applying custom resources)
  echo "Test 2: Operator Readiness..."
  echo "Checking KubeRay Operator..."
  kubectl wait --for=condition=available deployment/kuberay-operator -n default --timeout=15m || {
    echo "KubeRay Operator failed to become ready."
    kubectl describe deployment kuberay-operator -n default
    kubectl get pods -l app.kubernetes.io/name=kuberay-operator -A
    exit 1
  }

  echo "Checking Kueue Operator..."
  kubectl wait --for=condition=available deployment/kueue-controller-manager -n kueue-system --timeout=15m || {
    echo "Kueue Operator failed to become ready."
    kubectl describe deployment kueue-controller-manager -n kueue-system
    kubectl get pods -l control-plane=controller-manager -n kueue-system
    kubectl logs -l control-plane=controller-manager -n kueue-system --all-containers --tail=100
    exit 1
  }
  echo "Operators are ready."

  # 2.5 Apply Custom Resources (after webhooks are ready)
  echo "Applying Custom Resources..."
  # Re-apply with --server-side to ensure any webhook-mutated fields are preserved
  kubectl apply --server-side -f "$WORKLOAD_DIR/02-kueue-config.yaml"
  kubectl apply --server-side -f "$WORKLOAD_DIR/03-ray-clusters.yaml"
else
  echo "Warning: config-connector-workload directory not found at $WORKLOAD_DIR"
  # If we are in TF path and directory is missing (unlikely given PR files), 
  # we still expect operators to be present from Helm.
  echo "Checking Operator Readiness (expecting Helm install)..."
  kubectl wait --for=condition=available deployment/kuberay-operator -n default --timeout=15m || {
    echo "KubeRay Operator (Helm) failed to become ready."
    kubectl describe deployment kuberay-operator -n default
    exit 1
  }
  kubectl wait --for=condition=available deployment/kueue-controller-manager -n kueue-system --timeout=15m || {
    echo "Kueue Operator (Helm) failed to become ready."
    kubectl describe deployment kueue-controller-manager -n kueue-system
    exit 1
  }
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
    echo "Error: Kueue resources failed to become present."
    exit 1
  fi
done

# 4. RayCluster Readiness
echo "Test 4: RayCluster Readiness..."
# RayClusters take time to provision head pods and GPU worker nodes
# Increase timeout to 25m to allow for GPU node provisioning
set +e
kubectl wait --for=jsonpath='{.status.state}'=ready raycluster/raycluster-team-a -n team-a --timeout=25m
RESULT_A=$?
kubectl wait --for=jsonpath='{.status.state}'=ready raycluster/raycluster-team-b -n team-b --timeout=25m
RESULT_B=$?
set -e

if [ $RESULT_A -ne 0 ] || [ $RESULT_B -ne 0 ]; then
  echo "Error: RayClusters failed to become ready."
  echo "=== Debug Info: Pods ==="
  kubectl get pods -A
  echo "=== Debug Info: RayClusters ==="
  kubectl get raycluster -A
  echo "=== Debug Info: Events ==="
  kubectl get events -A --sort-by='.lastTimestamp' | tail -n 50
  exit 1
fi
echo "RayClusters are ready."

echo "All Validation Tests passed successfully!"
