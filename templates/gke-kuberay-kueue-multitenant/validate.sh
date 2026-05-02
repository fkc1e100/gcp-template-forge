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

# Check if we are running in KCC path or TF path
IS_KCC=false
if [[ "$CLUSTER_NAME" == *"-kcc" ]] || [[ "$CLUSTER_NAME" == *"-tf" && -z "$TF_VAR_project_id" ]]; then
  # The runner will provide KCC_NAMESPACE or we can infer it. 
  # Wait, in KCC sandbox we will just check if we have config-connector-workload and KCC_NAMESPACE is set, but KCC_NAMESPACE is for forge-management.
  # If we see that the operators aren't running, we might be in KCC.
  IS_KCC=true
fi
if kubectl get pods -l app.kubernetes.io/name=kuberay-operator -A >/dev/null 2>&1; then
  if kubectl get pods -l app.kubernetes.io/name=kuberay-operator -A -o jsonpath='{.items[*].status.phase}' | grep -q "Running"; then
    IS_KCC=false
  else
    # They are there but not running yet?
    :
  fi
else
  # No pods found, must be KCC needing apply
  IS_KCC=true
fi

# The surest way: in TF CI, Helm has already applied the workloads before validate.sh is called.
# In KCC CI, Helm is not used, so the workloads must be applied now.
echo "Applying workloads if necessary..."
if [[ "$IS_KCC" == "true" ]]; then
  echo "Applying operators (KCC path)..."
  kubectl create namespace kuberay-operator --dry-run=client -o yaml | kubectl apply -f -
  kubectl create namespace kueue-system --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply --server-side -f templates/gke-kuberay-kueue-multitenant/config-connector-workload/kuberay-operator.yaml
  kubectl apply --server-side -f templates/gke-kuberay-kueue-multitenant/config-connector-workload/kueue-operator.yaml
fi

# Wait for KubeRay operator
echo "Waiting for KubeRay operator..."
kubectl wait --for=condition=available deployment/kuberay-operator -n kuberay-operator --timeout=120s

# Wait for Kueue operator
echo "Waiting for Kueue operator..."
kubectl wait --for=condition=available deployment/kueue-controller-manager -n kueue-system --timeout=120s

# Wait for CRDs to be registered
echo "Waiting for Kueue CRDs..."
for i in {1..30}; do
  if kubectl get crd resourceflavors.kueue.x-k8s.io clusterqueues.kueue.x-k8s.io localqueues.kueue.x-k8s.io >/dev/null 2>&1; then
    echo "Kueue CRDs are ready"
    break
  fi
  echo "Waiting for Kueue CRDs... ($i/30)"
  sleep 10
done

echo "Waiting for KubeRay CRDs..."
for i in {1..30}; do
  if kubectl get crd rayclusters.ray.io >/dev/null 2>&1; then
    echo "KubeRay CRDs are ready"
    break
  fi
  echo "Waiting for KubeRay CRDs... ($i/30)"
  sleep 10
done

# Apply multi-tenant configuration
echo "Applying multi-tenant configuration..."
if [[ "$IS_KCC" == "true" ]]; then
  if ! kubectl get resourceflavor default-flavor >/dev/null 2>&1; then
    echo "Applying KCC workload.yaml..."
    kubectl apply -f templates/gke-kuberay-kueue-multitenant/config-connector-workload/workload.yaml
  fi
else
  if ! kubectl get resourceflavor default-flavor >/dev/null 2>&1; then
    echo "Applying TF extra manifests..."
    kubectl apply -f templates/gke-kuberay-kueue-multitenant/terraform-helm/workload/extra-manifests/
  fi
fi

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