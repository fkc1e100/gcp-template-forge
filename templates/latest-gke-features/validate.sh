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

echo "Starting Latest GKE Features Validation Tests..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
REGION=${REGION:-"us-central1"}
NAMESPACE=${NAMESPACE:-"default"}

# 0. Cluster Detection
if [ -z "${CLUSTER_NAME}" ]; then
  echo "CLUSTER_NAME not set, attempting to detect cluster..."
  if gcloud container clusters describe latest-gke-features-tf --region ${REGION} --project ${PROJECT_ID} >/dev/null 2>&1; then
    CLUSTER_NAME="latest-gke-features-tf"
    echo "Detected Terraform cluster: ${CLUSTER_NAME}"
  elif gcloud container clusters describe latest-gke-features-kcc --region ${REGION} --project ${PROJECT_ID} >/dev/null 2>&1; then
    CLUSTER_NAME="latest-gke-features-kcc"
    echo "Detected Config Connector cluster: ${CLUSTER_NAME}"
  else
    echo "ERROR: Could not detect GKE cluster. Please set CLUSTER_NAME environment variable."
    exit 1
  fi
fi

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
# Try both Helm-style name and KCC manifest name
DEPLOY_NAME="release-latest-features-workload"
if ! kubectl get deployment "$DEPLOY_NAME" -n "${NAMESPACE}" >/dev/null 2>&1; then
  DEPLOY_NAME="latest-features-workload"
fi

# Auto-detect namespace if not found in provided NAMESPACE
if ! kubectl get deployment "$DEPLOY_NAME" -n "${NAMESPACE}" >/dev/null 2>&1; then
  echo "Deployment $DEPLOY_NAME not found in namespace ${NAMESPACE}. Searching for it..."
  # Try latest-features namespace as it's the default in KCC manifests
  if kubectl get deployment "$DEPLOY_NAME" -n "latest-features" >/dev/null 2>&1; then
    echo "Found deployment in namespace: latest-features"
    NAMESPACE="latest-features"
  else
    # Fallback to label search
    SEARCH_NS=$(kubectl get deployment --all-namespaces -l app.kubernetes.io/name=latest-features-workload -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)
    if [ -n "$SEARCH_NS" ]; then
      echo "Found deployment in namespace: $SEARCH_NS"
      NAMESPACE="$SEARCH_NS"
    fi
  fi
fi

echo "Waiting for deployment ${DEPLOY_NAME} in namespace ${NAMESPACE}..."
kubectl wait --for=condition=available deployment/${DEPLOY_NAME} -n ${NAMESPACE} --timeout=30m
echo "Workload is available."

# 3. Native Sidecar Validation
echo "Test 3: Native Sidecar Validation..."
# Try both Helm-style label and simpler label
POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/name=latest-features-workload -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
  # Fallback for older or different label schemes
  POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=latest-features-workload -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
fi

if [ -z "$POD_NAME" ]; then
  echo "Native Sidecar check failed! No pods found with label app.kubernetes.io/name=latest-features-workload."
  exit 1
fi

RESTART_POLICY=$(kubectl get pod ${POD_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.initContainers[0].restartPolicy}')
if [ "$RESTART_POLICY" != "Always" ]; then
  echo "Native Sidecar check failed! restartPolicy is $RESTART_POLICY, expected Always."
  exit 1
fi
echo "Native Sidecar validated (restartPolicy: Always found)."

# 4. Gateway API Validation
echo "Test 4: Gateway API Validation..."
# Check if Gateway is programmed
kubectl wait --for=condition=Programmed gateway/latest-features-gateway -n ${NAMESPACE} --timeout=30m

# Get Gateway IP
GATEWAY_IP=$(kubectl get gateway latest-features-gateway -n ${NAMESPACE} -o jsonpath='{.status.addresses[0].value}')
echo "Gateway IP: ${GATEWAY_IP}"

if [ -z "$GATEWAY_IP" ]; then
  echo "Failed to get Gateway IP!"
  exit 1
fi

echo "Testing endpoint http://${GATEWAY_IP}/..."
# Retry curl as the LB might take a few moments to actually start serving
for i in {1..30}; do
  if curl -sf --connect-timeout 5 --max-time 10 http://${GATEWAY_IP}/; then
    echo "Gateway endpoint test passed!"
    break
  fi
  echo "Gateway endpoint not ready (attempt $i/30)..."
  sleep 30
  if [ $i -eq 30 ]; then
    echo "Gateway endpoint test failed after 30 attempts!"
    exit 1
  fi
done

# 5. Image Streaming Check
echo "Test 5: Image Streaming Check..."
# Verify GCFS is enabled on the node pool
# Use the dynamic pool name (in TF it is ${CLUSTER_NAME}-pool)
NODE_POOL_NAME="${CLUSTER_NAME}-pool"
GCFS_ENABLED=$(gcloud container node-pools describe ${NODE_POOL_NAME} --cluster ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID} --format="value(config.gcfsConfig.enabled)")
if [ "$GCFS_ENABLED" != "True" ]; then
  echo "Image Streaming (GCFS) check failed! Enabled: $GCFS_ENABLED"
  exit 1
fi
echo "Image Streaming (GCFS) validated."

# 6. Node Pool Auto-provisioning (NAP) Check
echo "Test 6: Node Pool Auto-provisioning (NAP) Check..."
NAP_ENABLED=$(gcloud container clusters describe ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID} --format="value(autoscaling.enableNodeAutoprovisioning)")
if [ "$NAP_ENABLED" != "True" ]; then
  echo "NAP check failed! Enabled: $NAP_ENABLED"
  exit 1
fi
echo "Node Pool Auto-provisioning (NAP) validated."

# 7. Security Posture Check
echo "Test 7: Security Posture Check..."
SECURITY_POSTURE_MODE=$(gcloud container clusters describe ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID} --format="value(securityPostureConfig.mode)")
VULNERABILITY_MODE=$(gcloud container clusters describe ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID} --format="value(securityPostureConfig.vulnerabilityMode)")
if [ "$SECURITY_POSTURE_MODE" != "BASIC" ] || [ "$VULNERABILITY_MODE" != "VULNERABILITY_ENTERPRISE" ]; then
  echo "Security Posture check failed! Mode: $SECURITY_POSTURE_MODE, Vulnerability: $VULNERABILITY_MODE"
  exit 1
fi
echo "Security Posture validated (Enterprise Vulnerability scanning enabled)."

echo "All Latest GKE Features Validation Tests passed successfully!"
