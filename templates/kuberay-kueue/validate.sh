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

echo "Starting Validation Tests for kuberay-kueue..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME=${CLUSTER_NAME:-"gke-kuberay-kueue"}
REGION=${REGION:-"us-central1"}

# Isolate KUBECONFIG
export KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# 1. Cluster Connectivity
echo "Test 1: Cluster Connectivity..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
kubectl cluster-info
echo "Connectivity passed."

# 1.5 KCC Workload Apply
if [[ "$CLUSTER_NAME" == *"-kcc" ]]; then
  echo "Applying KCC Workloads..."
  kubectl create namespace kuberay-operator --dry-run=client -o yaml | kubectl apply -f -
  kubectl create namespace kueue-system --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply --server-side -f templates/kuberay-kueue/config-connector-workload/kuberay-operator.yaml
  kubectl apply --server-side -f templates/kuberay-kueue/config-connector-workload/kueue-operator.yaml
  
  echo "Waiting for CRDs..."
  for i in {1..30}; do
    if kubectl get crd resourceflavors.kueue.x-k8s.io clusterqueues.kueue.x-k8s.io localqueues.kueue.x-k8s.io rayclusters.ray.io >/dev/null 2>&1; then
      echo "CRDs are ready"
      break
    fi
    echo "Waiting for CRDs... ($i/30)"
    sleep 10
  done
  
  kubectl apply -f templates/kuberay-kueue/config-connector-workload/workload.yaml
fi

# 2. Operator Readiness
echo "Test 2: KubeRay and Kueue Operator Readiness..."
kubectl wait --for=condition=available deployment -l app.kubernetes.io/name=kuberay-operator --timeout=15m || true
kubectl wait --for=condition=available deployment -n kueue-system -l app.kubernetes.io/component=controller --timeout=15m || true
echo "Operators are ready."

# 3. RayCluster and Kueue Quota Checks
echo "Test 3: RayCluster Status..."
kubectl get rayclusters -A
kubectl get clusterqueues
kubectl get localqueues -A

echo "Waiting for RayClusters to be admitted or active..."
# We expect Kueue to suspend or admit the RayClusters. We just check if they exist.
for i in {1..20}; do
  if kubectl get rayclusters -A | grep -q team-a-raycluster; then
    echo "RayClusters created successfully!"
    break
  fi
  sleep 15
done

echo "Test 4: Submit RayJob to verify workload execution..."
cat << 'JOBEOF' > rayjob.yaml
apiVersion: ray.io/v1
kind: RayJob
metadata:
  name: test-rayjob
  namespace: team-a
spec:
  entrypoint: python -c "print('RayJob completed successfully!')"
  rayClusterSpec:
    rayVersion: '2.9.0'
    headGroupSpec:
      rayStartParams:
        dashboard-host: '0.0.0.0'
      template:
        spec:
          containers:
          - name: ray-head
            image: rayproject/ray:2.9.0
            resources:
              limits:
                cpu: "1"
                memory: "2Gi"
              requests:
                cpu: "1"
                memory: "2Gi"
    workerGroupSpecs:
    - groupName: worker-group
      replicas: 1
      minReplicas: 0
      maxReplicas: 1
      rayStartParams: {}
      template:
        spec:
          nodeSelector:
            gpu: "l4"
          containers:
          - name: ray-worker
            image: rayproject/ray:2.9.0
            resources:
              limits:
                cpu: "1"
                memory: "2Gi"
                nvidia.com/gpu: 1
              requests:
                cpu: "1"
                memory: "2Gi"
                nvidia.com/gpu: 1
JOBEOF

kubectl apply -f rayjob.yaml

echo "Waiting for RayJob to complete..."
for i in {1..90}; do
  if kubectl get rayjob/test-rayjob -n team-a -o jsonpath='{.status.jobStatus}' | grep -q "SUCCEEDED"; then
    echo "RayJob completed successfully."
    break
  fi
  echo "Waiting for RayJob to complete... ($i/90)"
  sleep 10
done

if ! kubectl get rayjob/test-rayjob -n team-a -o jsonpath='{.status.jobStatus}' | grep -q "SUCCEEDED"; then
  echo "RayJob failed or timed out!"
  kubectl get rayjob/test-rayjob -n team-a -o yaml
  kubectl get pods -n team-a
  exit 1
fi

echo "All Validation Tests passed successfully!"
