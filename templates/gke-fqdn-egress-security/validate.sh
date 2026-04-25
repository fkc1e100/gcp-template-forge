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
CLUSTER_NAME=${CLUSTER_NAME:-"gke-fqdn-egress-security"}
REGION=${REGION:-"us-central1"}
NAMESPACE=${NAMESPACE:-"default"}

# Isolate KUBECONFIG to avoid affecting other clusters
export KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# 1. Cluster Connectivity
echo "Test 1: Cluster Connectivity..."
if ! gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${REGION}" --project "${PROJECT_ID}"; then
  echo "FAILURE: Failed to get cluster credentials."
  exit 1
fi

if ! kubectl cluster-info; then
  echo "FAILURE: Cannot reach cluster API server."
  echo "--- DEBUG INFO ---"
  gcloud container clusters describe "${CLUSTER_NAME}" --region "${REGION}" --project "${PROJECT_ID}" --format="value(status,statusMessage)" || true
  exit 1
fi
echo "Connectivity passed."

# 2. Dataplane V2 and FQDN Policy Enablement
echo "Test 2: Verifying Dataplane V2 and FQDN Policy Enablement..."
CLUSTER_DESC=$(gcloud container clusters describe "${CLUSTER_NAME}" --region "${REGION}" --project "${PROJECT_ID}" --format=json)
DATAPATH=$(echo "${CLUSTER_DESC}" | jq -r '.networkConfig.datapathProvider')
FQDN_ENABLED=$(echo "${CLUSTER_DESC}" | jq -r '.networkConfig.enableFqdnNetworkPolicy')

if [[ "$DATAPATH" != "ADVANCED_DATAPATH" ]]; then
  echo "FAILURE: Dataplane V2 check failed! Provider: $DATAPATH"
  echo "--- DEBUG INFO ---"
  echo "Dataplane V2 (ADVANCED_DATAPATH) is required for FQDN Network Policies."
  echo "Full Network Config:"
  echo "${CLUSTER_DESC}" | jq '.networkConfig'
  exit 1
fi
if [[ "$FQDN_ENABLED" != "true" ]]; then
  echo "FAILURE: FQDN Network Policy check failed! Enabled: $FQDN_ENABLED"
  echo "--- DEBUG INFO ---"
  echo "The enableFqdnNetworkPolicy flag must be set to true."
  exit 1
fi
echo "Dataplane V2 and FQDN Policy enablement validated."

# 3. FQDNNetworkPolicy Resource Verification
echo "Test 3: Verifying FQDNNetworkPolicy Resource..."
echo "Waiting for FQDNNetworkPolicy CRD to be available..."
CRD_FOUND=false
for i in {1..30}; do
  if kubectl get crd fqdnnetworkpolicies.networking.gke.io > /dev/null 2>&1; then
    echo "CRD found!"
    CRD_FOUND=true
    break
  fi
  echo "Still waiting for CRD (attempt $i/30)..."
  sleep 10
done

if [[ "$CRD_FOUND" == "false" ]]; then
  echo "FAILURE: FQDNNetworkPolicy CRD not found after 5 minutes."
  echo "--- DEBUG INFO ---"
  kubectl get crd | grep networking.gke.io || true
  echo "Check if GKE Enterprise is enabled and the cluster is registered to a fleet."
  exit 1
fi

if ! kubectl get fqdnnetworkpolicies.networking.gke.io allow-ai-egress -n "${NAMESPACE}"; then
  echo "FAILURE: FQDNNetworkPolicy 'allow-ai-egress' not found in namespace ${NAMESPACE}."
  echo "--- DEBUG INFO ---"
  kubectl get fqdnnetworkpolicies.networking.gke.io -A || true
  exit 1
fi
echo "FQDNNetworkPolicy resource found and verified."

# 4. Wait for Verifier Pod
echo "Test 4: Waiting for Egress Verifier Pod..."
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
  echo "--- DEBUG INFO ---"
  kubectl get pods -n "${NAMESPACE}" || true
  kubectl get events -n "${NAMESPACE}" --sort-by='.lastTimestamp' | tail -n 20 || true
  exit 1
fi

if ! kubectl wait --for=condition=Ready pod/egress-verifier -n "${NAMESPACE}" --timeout=5m; then
  echo "FAILURE: egress-verifier pod failed to become ready."
  echo "--- DEBUG INFO ---"
  kubectl describe pod egress-verifier -n "${NAMESPACE}" || true
  kubectl logs egress-verifier -n "${NAMESPACE}" || true
  exit 1
fi
echo "Verifier pod is ready."

# 5. Egress Tests
echo "Test 5: Running Egress Tests..."

# Helper function to test domain connectivity with retries
test_domain() {
  local domain=$1
  local expected_success=$2
  local max_retries=12
  local success=false

  echo "Testing domain: $domain (Expected: $expected_success)..."

  for i in $(seq 1 $max_retries); do
    if kubectl exec egress-verifier -n "${NAMESPACE}" -- curl -sL -4 --connect-timeout 10 "https://$domain" > /dev/null 2>&1; then
      success=true
      if [[ "$expected_success" == "true" ]]; then
        echo "SUCCESS: $domain is reachable (attempt $i)."
        return 0
      fi
    else
      if [[ "$expected_success" == "false" ]]; then
        echo "SUCCESS: $domain is blocked as expected (attempt $i)."
        return 0
      fi
    fi
    
    if [[ "$expected_success" == "true" ]]; then
      echo "Attempt $i: $domain not reachable yet, retrying in 5s..."
    else
      echo "Attempt $i: $domain still reachable, retrying in 5s (waiting for policy propagation)..."
    fi
    sleep 5
  done

  if [[ "$expected_success" == "true" ]]; then
    echo "FAILURE: $domain is NOT reachable after $max_retries attempts."
  else
    echo "FAILURE: $domain is reachable, but should be blocked!"
  fi

  echo "--- DEBUG INFO ---"
  kubectl get fqdnnetworkpolicies.networking.gke.io allow-ai-egress -n "${NAMESPACE}" -o yaml || true
  kubectl get networkpolicies -n "${NAMESPACE}" -o yaml || true
  echo "Checking pod status and labels..."
  kubectl get pod egress-verifier -n "${NAMESPACE}" --show-labels || true
  echo "Attempting a direct curl with verbose output..."
  kubectl exec egress-verifier -n "${NAMESPACE}" -- curl -v -4 --connect-timeout 10 "https://$domain" || echo "kubectl exec failed"
  return 1
}

# Test Allowed Domains
test_domain "anthropic.com" "true"
test_domain "www.anthropic.com" "true" # Test wildcard *.anthropic.com
test_domain "api.anthropic.com" "true"
test_domain "huggingface.co" "true"
test_domain "www.huggingface.co" "true"
test_domain "hf.co" "true"
test_domain "www.hf.co" "true" # Test wildcard *.hf.co

# Test Blocked Domains
test_domain "google.com" "false"

echo "All GKE FQDN Network Policy Validation Tests passed successfully!"
