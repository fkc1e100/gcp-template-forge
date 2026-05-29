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
CLUSTER_NAME=${CLUSTER_NAME:-"gke-online-boutique-tf"}
REGION=${REGION:-"us-central1"}

# Isolate KUBECONFIG
export KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

echo "1. Cluster Connectivity..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
kubectl cluster-info
echo "Connectivity passed."

echo "2. Node Readiness..."
kubectl wait nodes --all --for=condition=Ready --timeout=10m
echo "All nodes are Ready."

# 2.5 Apply KCC Workloads (if KCC path)
if [[ "$CLUSTER_NAME" == *"-kcc" ]]; then
  echo "Applying KCC Workloads..."
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  kubectl apply -f "$DIR/config-connector-workload/online-boutique.yaml"
fi

echo "3. Workload Readiness..."
deployments=(
  "adservice"
  "cartservice"
  "checkoutservice"
  "currencyservice"
  "emailservice"
  "frontend"
  "paymentservice"
  "productcatalogservice"
  "recommendationservice"
  "shippingservice"
  "redis-cart"
)

echo "Waiting for all microservice deployments to become available..."
for dep in "${deployments[@]}"; do
  echo "Waiting for deployment: $dep..."
  kubectl wait --namespace default --for=condition=available "deployment/$dep" --timeout=600s
done
echo "All deployments are ready!"

# 4. Functional Verification
echo "4. Retrieving Frontend service external IP..."
SVC_NAME="frontend"
if [[ "$CLUSTER_NAME" == *"-kcc" ]]; then
  SVC_NAME="frontend-external"
fi

EXTERNAL_IP=""
MAX_ATTEMPTS=40
for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  EXTERNAL_IP=$(kubectl get svc "$SVC_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [[ -n "$EXTERNAL_IP" ]]; then
    echo "Found external IP: $EXTERNAL_IP"
    break
  fi
  echo "Waiting for external IP (attempt $i/$MAX_ATTEMPTS)..."
  sleep 10
done

if [[ -z "$EXTERNAL_IP" ]]; then
  echo "Error: Frontend external IP could not be resolved."
  exit 1
fi

echo "Performing functional verification curl test..."
CURL_SUCCESS=false
for ((i=1; i<=15; i++)); do
  echo "Curling external IP (attempt $i/15)..."
  RESPONSE=$(curl -sf "http://$EXTERNAL_IP" || true)
  if [[ "$RESPONSE" == *"Online Boutique"* ]]; then
    echo "Success: Online Boutique frontend is serving correctly!"
    CURL_SUCCESS=true
    break
  fi
  sleep 5
done

if [ "$CURL_SUCCESS" = false ]; then
  echo "Error: Did not receive expected response from Online Boutique frontend."
  exit 1
fi

echo "All Validation Tests passed successfully for GKE Online Boutique!"
