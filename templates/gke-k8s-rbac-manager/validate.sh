#!/usr/bin/env bash
set -e

PROJECT_ID=$(gcloud config get-value project)
CLUSTER_NAME="gke-k8s-rbac-manager-cluster"
ZONE="us-central1-a"

echo "Retrieving GKE credentials..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" --zone "${ZONE}" --project "${PROJECT_ID}"

echo "Waiting for test deployment to be available..."
kubectl wait --for=condition=available --timeout=300s deployment/rbac-manager-test -n default

echo "Verifying RBAC resources are present..."
kubectl get serviceaccount rbac-manager-sa -n default
kubectl get clusterrole rbac-manager-role
kubectl get clusterrolebinding rbac-manager-binding

echo "Testing RBAC functionality with 'auth can-i'..."

CAN_I_PODS=$(kubectl auth can-i list pods --as=system:serviceaccount:default:rbac-manager-sa)
if [ "${CAN_I_PODS}" = "yes" ]; then
    echo "✅ RBAC Test Passed: ServiceAccount CAN list pods."
else
    echo "❌ RBAC Test Failed: ServiceAccount CANNOT list pods."
    exit 1
fi

CAN_I_SECRETS=$(kubectl auth can-i list secrets --as=system:serviceaccount:default:rbac-manager-sa)
if [ "${CAN_I_SECRETS}" = "no" ]; then
    echo "✅ RBAC Test Passed: ServiceAccount CANNOT list secrets."
else
    echo "❌ RBAC Test Failed: ServiceAccount CAN list secrets (should be denied)."
    exit 1
fi

echo "All tests completed successfully!"
