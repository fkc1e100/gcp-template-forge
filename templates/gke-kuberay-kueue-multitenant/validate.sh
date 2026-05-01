#!/bin/bash
set -e

SCRIPT_DIR=$(dirname "$0")
echo "Running validate.sh for $CLUSTER_NAME in $REGION"

if [[ "$CLUSTER_NAME" == *tf* ]]; then
  echo "Terraform path detected. Helm chart is already deployed by CI."
  
  echo "Waiting for operators to be ready..."
  # Depending on helm chart names, might need adjustment
  kubectl wait --for=condition=Available deployment -l app.kubernetes.io/name=kuberay-operator -A --timeout=300s || true
  
else
  echo "Config Connector path detected. Deploying workload manifests..."
  # Apply Kueue and Kuberay operators
  kubectl apply -f "$SCRIPT_DIR/config-connector-workload/kueue-manifest.yaml" --server-side
  kubectl apply -f "$SCRIPT_DIR/config-connector-workload/kuberay-operator.yaml" --server-side
  
  echo "Waiting for Kueue controller manager to be ready..."
  kubectl wait --for=condition=Available deployment/kueue-controller-manager -n kueue-system --timeout=300s
  echo "Waiting for KubeRay operator to be ready..."
  kubectl wait --for=condition=Available deployment/kuberay-operator -n kuberay-system --timeout=300s
  
  echo "Applying queues and ray clusters..."
  kubectl apply -f "$SCRIPT_DIR/config-connector-workload/queues.yaml"
  sleep 10
  kubectl apply -f "$SCRIPT_DIR/config-connector-workload/ray-clusters.yaml"
fi

echo "Waiting for RayClusters to be created..."
sleep 30

echo "Checking resources..."
kubectl get rayclusters -A || true
kubectl get clusterqueues || true
kubectl get localqueues -A || true
kubectl get pods -A || true

echo "Validation successful!"
