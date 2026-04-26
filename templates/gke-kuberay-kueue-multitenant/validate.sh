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

echo "Starting GKE KubeRay Kueue Multitenant Validation Tests..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
REGION=${REGION:-"us-central1"}

# 0. Cluster Detection
if [ -z "${CLUSTER_NAME}" ]; then
  echo "CLUSTER_NAME not set, attempting to detect cluster..."
  if gcloud container clusters describe gke-ray-kueue-tf --region ${REGION} --project ${PROJECT_ID} >/dev/null 2>&1; then
    CLUSTER_NAME="gke-ray-kueue-tf"
    echo "Detected Terraform cluster: ${CLUSTER_NAME}"
  elif gcloud container clusters describe gke-ray-kueue-kcc --region ${REGION} --project ${PROJECT_ID} >/dev/null 2>&1; then
    CLUSTER_NAME="gke-ray-kueue-kcc"
    echo "Detected Config Connector cluster: ${CLUSTER_NAME}"
  else
    echo "ERROR: Could not detect GKE cluster. Please set CLUSTER_NAME environment variable."
    exit 1
  fi
fi

export KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

echo "Test 1: Cluster Connectivity..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
kubectl cluster-info
echo "Connectivity passed."

# If we are in the KCC path, we need to apply the workloads
if [[ "${CLUSTER_NAME}" == *"-kcc" ]]; then
  echo "Applying KCC workload manifests..."
  kubectl apply -f templates/gke-kuberay-kueue-multitenant/config-connector-workload/
fi

echo "Test 2: Waiting for Kueue to be Ready..."
kubectl wait --for=condition=available deployment/kueue-controller-manager -n kueue-system --timeout=15m

echo "Test 3: Waiting for KubeRay Operator to be Ready..."
kubectl wait --for=condition=available deployment/kuberay-operator -n kuberay-system --timeout=15m

echo "Test 4: Verify Equitable Queuing..."
# The cluster queue has 1 GPU. We deployed 2 RayClusters that need 1 GPU each.
# One should be Admitted, one should be Pending.
# Give it some time to reconcile.
sleep 30

ADMITTED=$(kubectl get clusterqueue cluster-queue -o jsonpath='{.status.admittedWorkloads}')
PENDING=$(kubectl get clusterqueue cluster-queue -o jsonpath='{.status.pendingWorkloads}')

echo "Admitted Workloads: ${ADMITTED}"
echo "Pending Workloads: ${PENDING}"

if [ "${ADMITTED}" -ge 1 ] && [ "${PENDING}" -ge 1 ]; then
  echo "Equitable queuing verified: one workload is admitted and the other is pending."
else
  echo "Equitable queuing check failed!"
  # Print some debug info
  kubectl get localqueues -A
  kubectl get clusterqueues
  kubectl get rayclusters -A
  # Try to exit 1, but maybe the reconciliation is slow. Let's try again in a loop.
fi

# Retry loop for Kueue admission
for i in {1..30}; do
  ADMITTED=$(kubectl get clusterqueue cluster-queue -o jsonpath='{.status.admittedWorkloads}' || echo "0")
  PENDING=$(kubectl get clusterqueue cluster-queue -o jsonpath='{.status.pendingWorkloads}' || echo "0")
  
  if [ "$ADMITTED" != "0" ] && [ "$PENDING" != "0" ]; then
    echo "Successfully verified queuing."
    break
  fi
  echo "Waiting for Kueue admission... (Admitted: $ADMITTED, Pending: $PENDING)"
  sleep 15
  if [ $i -eq 30 ]; then
    echo "Failed to verify Kueue behavior after 30 attempts."
    exit 1
  fi
done

echo "All tests passed successfully!"
