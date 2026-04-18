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

# Verify replica count
FRONTEND_REPLICAS=$(kubectl get deployment frontend -n ${NAMESPACE} -o jsonpath='{.status.availableReplicas}' || echo "0")
BACKEND_REPLICAS=$(kubectl get deployment backend -n ${NAMESPACE} -o jsonpath='{.status.availableReplicas}' || echo "0")
FRONTEND_REPLICAS=${FRONTEND_REPLICAS:-0}
BACKEND_REPLICAS=${BACKEND_REPLICAS:-0}
echo "Frontend replicas: ${FRONTEND_REPLICAS}, Backend replicas: ${BACKEND_REPLICAS}"

if [ "${FRONTEND_REPLICAS}" -lt 3 ]; then
  echo "Error: Expected at least 3 frontend replicas, found ${FRONTEND_REPLICAS}"
  exit 1
fi
if [ "${BACKEND_REPLICAS}" -lt 3 ]; then
  echo "Error: Expected at least 3 backend replicas, found ${BACKEND_REPLICAS}"
  exit 1
fi
echo "Workloads are available and scaled correctly."

# 3. Topology Spread Check
echo "Test 3: Topology Spread Check..."
# Get zones of frontend pods by looking at the nodes they are running on
FRONTEND_NODES=$(kubectl get pods -l app=frontend -n ${NAMESPACE} -o jsonpath='{.items[*].spec.nodeName}')
FRONTEND_ZONES_LIST=$(for node in ${FRONTEND_NODES}; do kubectl get node ${node} -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}'; echo; done | sort | uniq | grep -v "^$")
FRONTEND_ZONES_COUNT=$(echo "${FRONTEND_ZONES_LIST}" | wc -l)
echo "Frontend pods are running in zones: $(echo ${FRONTEND_ZONES_LIST} | tr '\n' ' ') (Count: ${FRONTEND_ZONES_COUNT})"

# Get zones of backend pods by looking at the nodes they are running on
BACKEND_NODES=$(kubectl get pods -l app=backend -n ${NAMESPACE} -o jsonpath='{.items[*].spec.nodeName}')
BACKEND_ZONES_LIST=$(for node in ${BACKEND_NODES}; do kubectl get node ${node} -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}'; echo; done | sort | uniq | grep -v "^$")
BACKEND_ZONES_COUNT=$(echo "${BACKEND_ZONES_LIST}" | wc -l)
echo "Backend pods are running in zones: $(echo ${BACKEND_ZONES_LIST} | tr '\n' ' ') (Count: ${BACKEND_ZONES_COUNT})"

if [ "$FRONTEND_ZONES_COUNT" -lt 3 ]; then
  echo "Frontend pods are not spread across enough zones (found $FRONTEND_ZONES_COUNT, expected 3)."
  exit 1
fi
if [ "$BACKEND_ZONES_COUNT" -lt 3 ]; then
  echo "Backend pods are not spread across enough zones (found $BACKEND_ZONES_COUNT, expected 3)."
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

echo "Testing endpoint http://${GATEWAY_IP}/..."
# Retry curl as the LB might take a few moments to actually start serving
# Global Load Balancers can sometimes take up to 15 minutes to fully provision
for i in {1..30}; do
  if curl -sf --connect-timeout 5 --max-time 10 http://${GATEWAY_IP}/; then
    echo "Gateway endpoint test passed!"
    break
  fi
  echo "Gateway endpoint not ready (attempt $i/30)..."
  
  if [ $((i % 5)) -eq 0 ]; then
    echo "Debugging Gateway status..."
    kubectl describe gateway external-http -n ${NAMESPACE} || true
    kubectl describe httproute frontend-route -n ${NAMESPACE} || true
  fi

  sleep 30
  if [ $i -eq 30 ]; then
    echo "Gateway endpoint test failed after 30 attempts!"
    echo "Final Gateway and HTTPRoute status:"
    kubectl describe gateway external-http -n ${NAMESPACE}
    kubectl describe httproute frontend-route -n ${NAMESPACE}
    exit 1
  fi
done

echo "All GKE Topology-Aware Routing Validation Tests passed successfully!"
