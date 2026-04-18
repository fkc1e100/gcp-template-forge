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

echo "Starting GKE Topology-Aware Routing Validation Tests..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME=${CLUSTER_NAME:-"gke-topology-aware-routing-tf"}
REGION=${REGION:-"us-central1"}
NAMESPACE=${NAMESPACE:-"default"}

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
kubectl wait --for=condition=available deployment/frontend -n ${NAMESPACE} --timeout=10m
kubectl wait --for=condition=available deployment/backend -n ${NAMESPACE} --timeout=10m
echo "Workloads are available."

# 3. Topology Spread Check
echo "Test 3: Topology Spread Check..."
FRONTEND_ZONES=$(kubectl get pods -l app=frontend -n ${NAMESPACE} -o jsonpath='{.items[*].metadata.labels.topology\.kubernetes\.io/zone}' | tr ' ' '\n' | sort | uniq | wc -l)
BACKEND_ZONES=$(kubectl get pods -l app=backend -n ${NAMESPACE} -o jsonpath='{.items[*].metadata.labels.topology\.kubernetes\.io/zone}' | tr ' ' '\n' | sort | uniq | wc -l)

if [ "$FRONTEND_ZONES" -lt 2 ]; then
  echo "Frontend pods are not spread across enough zones (found $FRONTEND_ZONES)."
  exit 1
fi
if [ "$BACKEND_ZONES" -lt 2 ]; then
  echo "Backend pods are not spread across enough zones (found $BACKEND_ZONES)."
  exit 1
fi
echo "Topology spread validated."

# 4. Service Annotation Check
echo "Test 4: Service Annotation Check..."
MODE=$(kubectl get svc backend -n ${NAMESPACE} -o jsonpath='{.metadata.annotations.service\.kubernetes\.io/topology-mode}')
if [ "$MODE" != "Auto" ]; then
  echo "Topology mode annotation missing or incorrect! Found: $MODE"
  exit 1
fi
echo "Service topology-mode annotation validated."

# 5. EndpointSlice Hints Check
echo "Test 5: EndpointSlice Hints Check..."
# It might take a moment for the endpointslice controller to add hints
for i in {1..5}; do
  HINTS=$(kubectl get endpointslices -l kubernetes.io/service-name=backend -n ${NAMESPACE} -o jsonpath='{.items[*].endpoints[*].hints.forZones[*].name}')
  if [ -n "$HINTS" ]; then
    echo "EndpointSlice hints found: $HINTS"
    break
  fi
  echo "Waiting for EndpointSlice hints (attempt $i/5)..."
  sleep 10
done

if [ -z "$HINTS" ]; then
  echo "EndpointSlice hints not found!"
  exit 1
fi
echo "EndpointSlice hints validated."

# 6. Gateway API Validation
echo "Test 6: Gateway API Validation..."
kubectl wait --for=condition=Programmed gateway/external-http -n ${NAMESPACE} --timeout=15m
GATEWAY_IP=$(kubectl get gateway external-http -n ${NAMESPACE} -o jsonpath='{.status.addresses[0].value}')
echo "Gateway IP: ${GATEWAY_IP}"

if [ -z "$GATEWAY_IP" ]; then
  echo "Failed to get Gateway IP!"
  exit 1
fi

echo "All GKE Topology-Aware Routing Validation Tests passed successfully!"
