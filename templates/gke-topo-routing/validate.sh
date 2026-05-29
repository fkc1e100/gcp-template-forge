#!/bin/bash
set -e

echo "Waiting for topo-app deployment to be ready (replicas distributed across zones)..."
kubectl wait --for=condition=Available deployment/topo-app --timeout=300s

echo "Checking if EndpointSlice contains topology hints..."
# The EndpointSlice controller might take a few seconds to calculate and apply hints.
sleep 15

# Retrieve the EndpointSlice associated with the service and extract the zone hints
HINTS=$(kubectl get endpointslices -l kubernetes.io/service-name=topo-svc -o jsonpath='{.items[*].endpoints[*].hints.forZones[*].name}')

if [[ -z "$HINTS" ]]; then
    echo "Error: No topology hints found in EndpointSlice. Topology-aware routing may not be functioning correctly."
    echo "Dumping EndpointSlice state for debugging:"
    kubectl get endpointslices -l kubernetes.io/service-name=topo-svc -o yaml
    exit 1
fi

echo "Topology hints are successfully generated for the following zones: $HINTS"
echo "Validation passed! Topology-aware routing is active."
