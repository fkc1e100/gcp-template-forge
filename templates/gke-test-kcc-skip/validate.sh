#!/usr/bin/env bash
set -e

CLUSTER_NAME=$1
REGION=$2
PROJECT_ID=$3

echo "Validating GKE Cluster workload deployment..."

gcloud container clusters get-credentials "$CLUSTER_NAME" --region "$REGION" --project "$PROJECT_ID"

kubectl get deployments
kubectl get svc

echo "Wait for sample-workload deployment..."
kubectl wait --for=condition=available --timeout=120s deployment/sample-workload

echo "Validation successful."
