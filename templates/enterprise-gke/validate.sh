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

# UPDATE: Replace 'gca-gke-2025' with your actual GCP Project ID
PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME=${CLUSTER_NAME:-"enterprise-gke-tf"}

# Handle CI-specific cluster naming (suffix with last 6 digits of run ID)
UID_SUFFIX=""
if [ -n "$GITHUB_RUN_ID" ]; then
  UID_SUFFIX="${GITHUB_RUN_ID: -6}"
fi

if [ "$CLUSTER_NAME" == "enterprise-gke-tf" ] && [ -n "$UID_SUFFIX" ]; then
  CLUSTER_NAME="enterprise-gke-${UID_SUFFIX}-tf"
  echo "Detected CI environment, using cluster name: ${CLUSTER_NAME}"
fi

REGION=${REGION:-"us-central1"}
NAMESPACE_WORKLOAD=${NAMESPACE_WORKLOAD:-"default"}

# Isolate KUBECONFIG
export KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# 1. Cluster Connectivity
echo "Test 1: Cluster Connectivity..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
kubectl cluster-info

# Auto-detect namespace if not explicitly set and not in default
if [ "$NAMESPACE_WORKLOAD" == "default" ]; then
  # List of namespaces to check in order of preference
  CHECK_NAMESPACES=("gke-workload")
  if [ -n "$UID_SUFFIX" ]; then
    CHECK_NAMESPACES=("gke-workload-${UID_SUFFIX}" "${CHECK_NAMESPACES[@]}")
  fi

  # Check if workload exists in current NAMESPACE_WORKLOAD
  if ! kubectl get deployment release-enterprise-workload -n "${NAMESPACE_WORKLOAD}" >/dev/null 2>&1; then
    FOUND=false
    for ns in "${CHECK_NAMESPACES[@]}"; do
      if kubectl get deployment release-enterprise-workload -n "${ns}" >/dev/null 2>&1; then
        echo "Workload found in ${ns} namespace, switching context..."
        NAMESPACE_WORKLOAD="${ns}"
        FOUND=true
        break
      fi
    done

    if [ "$FOUND" = false ]; then
      # Fallback: search across all namespaces for the deployment
      echo "Workload not found in standard namespaces, searching across all namespaces..."
      # Use jsonpath for cleaner detection and prefer ones with UID_SUFFIX if available (sort -r)
      DETECTED_NS=$(kubectl get deployments --all-namespaces -l app.kubernetes.io/instance=release -o jsonpath='{range .items[?(@.metadata.name=="release-enterprise-workload")]}{.metadata.namespace}{"\n"}{end}' | sort -r | head -n 1)

      if [ -n "$DETECTED_NS" ]; then
        echo "Workload found in ${DETECTED_NS} namespace, switching context..."
        NAMESPACE_WORKLOAD="$DETECTED_NS"
      else
        echo "Warning: Could not auto-detect workload namespace. Falling back to ${NAMESPACE_WORKLOAD}"
      fi
    fi
  fi
fi

echo "Using namespace: ${NAMESPACE_WORKLOAD}"
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
  labels:
    app: test-workload-identity
    project: gcp-template-forge
    template: enterprise-gke
spec:
  template:
    metadata:
      labels:
        app: test-workload-identity
        project: gcp-template-forge
        template: enterprise-gke
    spec:
      serviceAccountName: ${SA_NAME}
      containers:
      - name: gcloud
        image: google/cloud-sdk:slim
        command: ["gcloud", "auth", "list"]
      restartPolicy: Never
  backoffLimit: 1
EOF

JOB_NAME=$(kubectl get jobs -n ${NAMESPACE_WORKLOAD} -l app=test-workload-identity --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
kubectl wait --for=condition=complete job/${JOB_NAME} --timeout=5m -n ${NAMESPACE_WORKLOAD}
kubectl logs job/${JOB_NAME} -n ${NAMESPACE_WORKLOAD}
kubectl delete job ${JOB_NAME} -n ${NAMESPACE_WORKLOAD}
echo "Workload Identity validated."

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
