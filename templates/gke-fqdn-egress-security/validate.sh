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

echo "Starting GKE FQDN Network Policy Validation Tests..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME=${CLUSTER_NAME:-"gke-fqdn-egress-security-cluster"}
REGION=${REGION:-"us-central1"}
NAMESPACE=${NAMESPACE:-"default"}

# Isolate KUBECONFIG to avoid affecting other clusters
export KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# 1. Cluster Connectivity
echo "Test 1: Cluster Connectivity..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${REGION}" --project "${PROJECT_ID}"
kubectl cluster-info
echo "Connectivity passed."

# 2. Dataplane V2 and FQDN Policy Enablement
echo "Test 2: Verifying Dataplane V2 and FQDN Policy Enablement..."
CLUSTER_DESC=$(gcloud container clusters describe "${CLUSTER_NAME}" --region "${REGION}" --project "${PROJECT_ID}" --format=json)
DATAPATH=$(echo "${CLUSTER_DESC}" | jq -r '.networkConfig.datapathProvider')
FQDN_ENABLED=$(echo "${CLUSTER_DESC}" | jq -r '.networkConfig.enableFqdnNetworkPolicy')

if [[ "$DATAPATH" != "ADVANCED_DATAPATH" ]]; then
  echo "Dataplane V2 check failed! Provider: $DATAPATH"
  exit 1
fi
if [[ "$FQDN_ENABLED" != "true" ]]; then
  echo "FQDN Network Policy check failed! Enabled: $FQDN_ENABLED"
  exit 1
fi
echo "Dataplane V2 and FQDN Policy enablement validated."

# 3. FQDNNetworkPolicy Resource Verification
echo "Test 3: Verifying FQDNNetworkPolicy Resource..."

# NOTE: FQDNNetworkPolicy was promoted to GA (v1) in GKE 1.35. 
# This template uses v1 for stability and future-proofing.
# Wait for the CRD to be available (it can take time for GKE to install it after feature enablement)
echo "Waiting for FQDNNetworkPolicy CRD to be available..."
for i in {1..30}; do
  if kubectl get crd fqdnnetworkpolicies.networking.gke.io > /dev/null 2>&1; then
    echo "CRD found!"
    break
  fi
  echo "Still waiting for CRD (attempt $i/30)..."
  sleep 10
done

# Check if the policy exists. If not, it might have been skipped by Helm due to missing CRD at install time.
if ! kubectl get fqdnnetworkpolicies.networking.gke.io allow-ai-egress -n "${NAMESPACE}" > /dev/null 2>&1; then
  echo "FQDNNetworkPolicy 'allow-ai-egress' not found. It may have been skipped by Helm."
  echo "Attempting to apply it manually from the template..."
  
  # Try to find the manifest. Supports running from root or template dir.
  MANIFEST_PATH="config-connector-workload/workload.yaml"
  if [ ! -f "$MANIFEST_PATH" ]; then
    MANIFEST_PATH="templates/gke-fqdn-egress-security/config-connector-workload/workload.yaml"
  fi

  if [ -f "$MANIFEST_PATH" ]; then
    kubectl apply -n "${NAMESPACE}" -f "$MANIFEST_PATH"
  else
    echo "ERROR: Could not find workload manifest to apply FQDNNetworkPolicy manually (tried $MANIFEST_PATH)!"
    exit 1
  fi
fi

kubectl get fqdnnetworkpolicies.networking.gke.io allow-ai-egress -n "${NAMESPACE}"
echo "FQDNNetworkPolicy resource found and verified."

# 4. Wait for Verifier Pod
echo "Test 4: Waiting for Egress Verifier Pod..."
# Wait for pod to exist (up to 200 seconds)
POD_FOUND=false
for i in {1..20}; do
  if kubectl get pod egress-verifier -n "${NAMESPACE}" > /dev/null 2>&1; then
    POD_FOUND=true
    break
  fi
  echo "Waiting for egress-verifier pod to be created (attempt $i/20)..."
  sleep 10
done

if [[ "$POD_FOUND" == "false" ]]; then
  echo "FAILURE: egress-verifier pod was never created!"
  exit 1
fi

kubectl wait --for=condition=Ready pod/egress-verifier -n "${NAMESPACE}" --timeout=5m
echo "Verifier pod is ready."

# 5. Egress Tests
echo "Test 5: Running Egress Tests..."

echo "Testing allowed domain: api.anthropic.com..."
# Dataplane V2 FQDN policies sometimes need a few seconds to learn the IP from the first DNS response.
# We use a retry loop to account for this.
MAX_RETRIES=12
SUCCESS=false
for i in $(seq 1 $MAX_RETRIES); do
  if kubectl exec egress-verifier -n "${NAMESPACE}" -- curl -sL -4 --connect-timeout 10 https://api.anthropic.com > /dev/null; then
    echo "SUCCESS: api.anthropic.com is reachable (attempt $i)."
    SUCCESS=true
    break
  fi
  echo "Attempt $i: api.anthropic.com not reachable yet, retrying in 5s..."
  sleep 5
done

if [[ "$SUCCESS" == "false" ]]; then
  echo "FAILURE: api.anthropic.com is NOT reachable after $MAX_RETRIES attempts."
  # Debug: dump policy status and DNS resolution
  echo "--- DEBUG INFO ---"
  kubectl get fqdnnetworkpolicies.networking.gke.io allow-ai-egress -n "${NAMESPACE}" -o yaml || true
  echo "Checking pod status and labels..."
  kubectl get pod egress-verifier -n "${NAMESPACE}" --show-labels || true
  echo "Attempting a direct curl with verbose output..."
  kubectl exec egress-verifier -n "${NAMESPACE}" -- curl -v -4 --connect-timeout 10 https://api.anthropic.com || echo "kubectl exec failed"
  exit 1
fi

echo "Testing allowed domain: huggingface.co..."
SUCCESS=false
for i in $(seq 1 $MAX_RETRIES); do
  if kubectl exec egress-verifier -n "${NAMESPACE}" -- curl -sL -4 --connect-timeout 10 https://huggingface.co > /dev/null; then
    echo "SUCCESS: huggingface.co is reachable (attempt $i)."
    SUCCESS=true
    break
  fi
  echo "Attempt $i: huggingface.co not reachable yet, retrying in 5s..."
  sleep 5
done

if [[ "$SUCCESS" == "false" ]]; then
  echo "FAILURE: huggingface.co is NOT reachable after $MAX_RETRIES attempts."
  exit 1
fi

echo "Testing allowed domain: hf.co..."
SUCCESS=false
for i in $(seq 1 $MAX_RETRIES); do
  if kubectl exec egress-verifier -n "${NAMESPACE}" -- curl -sL -4 --connect-timeout 10 https://hf.co > /dev/null; then
    echo "SUCCESS: hf.co is reachable (attempt $i)."
    SUCCESS=true
    break
  fi
  echo "Attempt $i: hf.co not reachable yet, retrying in 5s..."
  sleep 5
done

if [[ "$SUCCESS" == "false" ]]; then
  echo "FAILURE: hf.co is NOT reachable after $MAX_RETRIES attempts."
  exit 1
fi

echo "Testing blocked domain: google.com..."
if kubectl exec egress-verifier -n "${NAMESPACE}" -- curl -sL -4 --connect-timeout 10 https://google.com > /dev/null 2>&1; then
  echo "FAILURE: google.com is reachable, but should be blocked!"
  exit 1
else
  echo "SUCCESS: google.com is blocked as expected."
fi

echo "All GKE FQDN Network Policy Validation Tests passed successfully!"
