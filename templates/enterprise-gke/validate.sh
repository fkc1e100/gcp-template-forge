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

echo "Starting Validation Tests for enterprise-gke..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME=${CLUSTER_NAME:-"enterprise-gke-tf"}
REGION=${REGION:-"us-central1"}
NAMESPACE_WORKLOAD=${NAMESPACE_WORKLOAD:-""}
if [ -z "$NAMESPACE_WORKLOAD" ]; then
  if kubectl get ns gke-workload >/dev/null 2>&1; then
    NAMESPACE_WORKLOAD="gke-workload"
  else
    NAMESPACE_WORKLOAD="default"
  fi
fi
echo "Using namespace: ${NAMESPACE_WORKLOAD}"

# Isolate KUBECONFIG
export KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# 1. Cluster Connectivity
echo "Test 1: Cluster Connectivity..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
kubectl cluster-info
echo "Connectivity passed."

# 2. Workload Readiness
echo "Test 2: Workload Readiness..."
# Deployment name from fullname helper: <release-name>-<chart-name>
# In CI, release name is 'release', chart name is 'enterprise-workload'
kubectl wait --for=condition=available deployment/release-enterprise-workload -n ${NAMESPACE_WORKLOAD} --timeout=15m
echo "Workload is available."

# 3. Workload Identity Integration
echo "Test 3: Workload Identity Integration..."
# Verify that the service account exists and is used by the pod
POD_NAME=$(kubectl get pods -n ${NAMESPACE_WORKLOAD} -l app.kubernetes.io/instance=release -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POD_NAME" ]; then
  echo "Failed to find workload pod!"
  exit 1
fi

SA_NAME=$(kubectl get pod ${POD_NAME} -n ${NAMESPACE_WORKLOAD} -o jsonpath='{.spec.serviceAccountName}')
echo "Workload is using ServiceAccount: ${SA_NAME}"

# Run a quick test job to verify WI connectivity (Cloud SDK check)
echo "Running Workload Identity test Job..."
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: test-workload-identity-$(date +%s)
  namespace: ${NAMESPACE_WORKLOAD}
spec:
  template:
    spec:
      serviceAccountName: ${SA_NAME}
      containers:
      - name: gcloud
        image: google/cloud-sdk:slim
        command: ["gcloud", "auth", "list"]
      restartPolicy: Never
  backoffLimit: 1
EOF

JOB_NAME=$(kubectl get jobs -n ${NAMESPACE_WORKLOAD} --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
if kubectl wait --for=condition=complete job/${JOB_NAME} --timeout=5m -n ${NAMESPACE_WORKLOAD}; then
  kubectl logs job/${JOB_NAME} -n ${NAMESPACE_WORKLOAD}
  echo "Workload Identity validated."
else
  echo "ERROR: Workload Identity validation failed or timed out."
  kubectl logs job/${JOB_NAME} -n ${NAMESPACE_WORKLOAD} || echo "Could not retrieve job logs."
  exit 1
fi
kubectl delete job ${JOB_NAME} -n ${NAMESPACE_WORKLOAD}

# 4. Endpoint Interaction
echo "Test 4: Endpoint Interaction..."
# Wait for LoadBalancer IP
SERVICE_IP=""
for i in {1..20}; do
  SERVICE_IP=$(kubectl get svc -n ${NAMESPACE_WORKLOAD} -l app.kubernetes.io/instance=release -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' || true)
  if [ ! -z "$SERVICE_IP" ]; then
    break
  fi
  echo "Waiting for LoadBalancer IP (attempt $i/20)..."
  sleep 30
done

if [ -z "$SERVICE_IP" ]; then
  echo "Failed to get LoadBalancer IP!"
  exit 1
fi

echo "Testing endpoint http://${SERVICE_IP}:80/..."
# Retry curl as the LB might take a few moments to actually start serving
for i in {1..12}; do
  if curl -sf --connect-timeout 5 --max-time 10 http://${SERVICE_IP}:80/; then
    echo "Endpoint test passed!"
    break
  fi
  echo "Endpoint not ready (attempt $i/12)..."
  sleep 30
  if [ $i -eq 12 ]; then
    echo "Endpoint test failed after 12 attempts!"
    exit 1
  fi
done

echo "All Validation Tests passed successfully!"
# CI Trigger - Turn 105
 
