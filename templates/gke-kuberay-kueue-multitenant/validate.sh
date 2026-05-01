#!/bin/bash
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

echo "Starting validation for ray-kueue template..."

# Check if KubeRay operator is running
echo "Checking KubeRay operator..."
kubectl get pods -l app.kubernetes.io/name=kuberay-operator -A
KUBERAY_PODS=$(kubectl get pods -l app.kubernetes.io/name=kuberay-operator -A -o jsonpath='{.items[*].status.phase}')
if [[ ! "$KUBERAY_PODS" =~ "Running" ]]; then
  echo "KubeRay operator is not running"
  exit 1
fi

# Check if Kueue operator is running
echo "Checking Kueue operator..."
kubectl get pods -l app.kubernetes.io/name=kueue -n kueue-system
KUEUE_PODS=$(kubectl get pods -l app.kubernetes.io/name=kueue -n kueue-system -o jsonpath='{.items[*].status.phase}')
if [[ ! "$KUEUE_PODS" =~ "Running" ]]; then
  echo "Kueue operator is not running"
  exit 1
fi

# Wait for CRDs to be registered
echo "Waiting for Kueue CRDs..."
for i in {1..20}; do
  if kubectl get crd resourceflavors.kueue.x-k8s.io clusterqueues.kueue.x-k8s.io localqueues.kueue.x-k8s.io >/dev/null 2>&1; then
    echo "Kueue CRDs are ready"
    break
  fi
  echo "Waiting for Kueue CRDs... ($i/20)"
  sleep 10
done

echo "Waiting for KubeRay CRDs..."
for i in {1..20}; do
  if kubectl get crd rayclusters.ray.io >/dev/null 2>&1; then
    echo "KubeRay CRDs are ready"
    break
  fi
  echo "Waiting for KubeRay CRDs... ($i/20)"
  sleep 10
done

# Apply multi-tenant configuration
echo "Applying multi-tenant configuration..."
kubectl apply -f templates/gke-kuberay-kueue-multitenant/terraform-helm/workload/extra-manifests/

# Check for ResourceFlavor
echo "Checking Kueue ResourceFlavor..."
kubectl get resourceflavor default-flavor

# Check for ClusterQueues
echo "Checking ClusterQueues..."
kubectl get clusterqueue team-a-cq
kubectl get clusterqueue team-b-cq

# Check for RayClusters
echo "Checking RayClusters..."
kubectl get raycluster -A

# Wait for RayCluster head pods to be ready
echo "Waiting for Ray head pods..."
kubectl wait --for=condition=Ready pod -l ray.io/node-type=head -n team-a --timeout=300s
kubectl wait --for=condition=Ready pod -l ray.io/node-type=head -n team-b --timeout=300s

echo "Validation successful!"
