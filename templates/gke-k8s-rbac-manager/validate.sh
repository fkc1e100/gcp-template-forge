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

set -euo pipefail

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME=${CLUSTER_NAME:-"gke-k8s-rbac-manager-tf"}
REGION=${REGION:-"us-central1"}
NAMESPACE_WORKLOAD=${NAMESPACE_WORKLOAD:-"default"}

# Isolate KUBECONFIG
export KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# 1. Cluster Connectivity
echo "Test 1: Cluster Connectivity..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
kubectl cluster-info
echo "Connectivity passed."

# 2. Node Readiness
echo "Test 2: Node Readiness..."
kubectl wait nodes --all --for=condition=Ready --timeout=10m
echo "All nodes are Ready."

# 2.5 Apply KCC Workloads
if [[ "$CLUSTER_NAME" == *"-kcc" ]]; then
  echo "Applying KCC Workloads..."
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  kubectl apply -f "$DIR/config-connector-workload/cluster.yaml"
  kubectl wait --for=condition=Established crd/clusters.example.com --timeout=5m
  kubectl apply -f "$DIR/config-connector-workload/rbac-manager-config.yaml"
fi

# 3. Workload Readiness
echo "Test 3: Workload Readiness (CRD and Custom Resource)..."
kubectl wait --for=condition=Established crd/clusters.example.com --timeout=5m
kubectl get clusters.example.com rbac-config -n ${NAMESPACE_WORKLOAD} -o yaml
echo "Workload is available."

# 4. Functional Verification
echo "Test 4: Functional Verification..."
ACTUAL_VAL=$(kubectl get clusters.example.com rbac-config -n ${NAMESPACE_WORKLOAD} -o jsonpath='{.spec.clusterName}')
if [ "$ACTUAL_VAL" == "k8s-rbac-managed-cluster" ]; then
  echo "Validation passed: spec.clusterName matches expected value."
else
  echo "Validation failed: expected 'k8s-rbac-managed-cluster', got '$ACTUAL_VAL'"
  exit 1
fi

echo "All Validation Tests passed successfully for K8s RBAC Manager!"
