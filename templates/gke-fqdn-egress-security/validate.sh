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
kubectl get fqdnnetworkpolicies.networking.gke.io allow-ai-egress -n "${NAMESPACE}"
echo "FQDNNetworkPolicy resource found."

# 4. Wait for Verifier Pod
echo "Test 4: Waiting for Egress Verifier Pod..."
# Wait for pod to exist
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
if kubectl exec egress-verifier -n "${NAMESPACE}" -- curl -sL --connect-timeout 5 https://api.anthropic.com > /dev/null; then
  echo "SUCCESS: api.anthropic.com is reachable."
else
  echo "FAILURE: api.anthropic.com is NOT reachable."
  exit 1
fi

echo "Testing allowed domain: huggingface.co..."
if kubectl exec egress-verifier -n "${NAMESPACE}" -- curl -sL --connect-timeout 5 https://huggingface.co > /dev/null; then
  echo "SUCCESS: huggingface.co is reachable."
else
  echo "FAILURE: huggingface.co is NOT reachable."
  exit 1
fi

echo "Testing blocked domain: google.com..."
if kubectl exec egress-verifier -n "${NAMESPACE}" -- curl -sL --connect-timeout 5 https://google.com > /dev/null 2>&1; then
  echo "FAILURE: google.com is reachable, but should be blocked!"
  exit 1
else
  echo "SUCCESS: google.com is blocked as expected."
fi

echo "All GKE FQDN Network Policy Validation Tests passed successfully!"
