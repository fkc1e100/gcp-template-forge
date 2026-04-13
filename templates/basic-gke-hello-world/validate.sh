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

echo "Starting KCC Validation Tests for basic-gke-hello-world..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME="gke-basic-kcc-v2"
NAMESPACE="forge-management"
NAMESPACE_WORKLOAD="hello-world"
REGION="us-central1"

# 1. Resource Readiness
echo "Test 1: Resource Readiness..."
kubectl wait --for=condition=Ready containercluster/${CLUSTER_NAME} --timeout=20m -n ${NAMESPACE}
echo "Resource Readiness passed."

# 2. Drift & Revert
echo "Test 2: Drift & Revert..."
# Make an out-of-band change using gcloud
gcloud container clusters update ${CLUSTER_NAME} --region ${REGION} --update-labels drift=test --project ${PROJECT_ID}
echo "Out-of-band change applied. Waiting for KCC to revert (sleeping 3m)..."
sleep 180
# Verify the label is removed by KCC
LABELS=$(gcloud container clusters describe ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID} --format="value(resourceLabels.drift)")
if [ ! -z "$LABELS" ]; then
  echo "Drift Revert failed! KCC did not revert the change."
  exit 1
fi
echo "Drift & Revert passed."

# 3. Workload Deployment (via Helm)
echo "Test 3: Workload Deployment (via Helm)..."
# Get credentials for the newly created cluster
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}

# Apply workload via Helm chart
echo "Installing Helm chart from terraform-helm/workload/..."
helm upgrade --install gke-basic terraform-helm/workload/ \
  --namespace ${NAMESPACE_WORKLOAD} \
  --create-namespace \
  --wait --timeout=10m

# 4. Endpoint Interaction
echo "Test 4: Endpoint Interaction..."
# Wait for LoadBalancer IP
SERVICE_IP=""
for i in {1..20}; do
  SERVICE_IP=$(kubectl get svc -n ${NAMESPACE_WORKLOAD} -l app.kubernetes.io/instance=gke-basic -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' || true)
  if [ ! -z "$SERVICE_IP" ]; then
    break
  fi
  echo "Waiting for LoadBalancer IP (attempt $i/20)..."
  sleep 30
done

if [ -z "$SERVICE_IP" ]; then
  echo "Failed to get LoadBalancer IP!"
  exit 1
fi

echo "Testing endpoint http://${SERVICE_IP}:80/..."
# Retry curl as the LB might take a few moments to actually start serving
for i in {1..10}; do
  if curl -sf http://${SERVICE_IP}:80/; then
    echo "Endpoint test passed!"
    break
  fi
  echo "Endpoint not ready (attempt $i/10)..."
  sleep 10
  if [ $i -eq 10 ]; then
    echo "Endpoint test failed after 10 attempts!"
    exit 1
  fi
done

# 5. Teardown Verification
echo "Test 5: Teardown Verification..."
# Delete workload via Helm
helm uninstall gke-basic -n ${NAMESPACE_WORKLOAD}

# Delete KCC manifests
kubectl delete containercluster/${CLUSTER_NAME} -n ${NAMESPACE} --wait=false
echo "Waiting for cluster deletion to start..."
for i in {1..20}; do
  STATUS=$(gcloud container clusters describe ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID} --format="value(status)" 2>/dev/null || echo "DELETED")
  if [ "$STATUS" == "STOPPING" ] || [ "$STATUS" == "DELETED" ]; then
    echo "Cluster status: $STATUS"
    break
  fi
  echo "Waiting for cluster to reach STOPPING (current: $STATUS)..."
  sleep 30
done

# Delete other KCC manifests
kubectl delete -f config-connector/ -n ${NAMESPACE} --ignore-not-found

echo "All KCC Validation Tests passed successfully!"
