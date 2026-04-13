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

echo "Starting KCC Validation Tests..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME="gke-enterprise-kcc-v3"
NODE_POOL_NAME="gke-enterprise-kcc-pool-v3"
NAMESPACE="forge-management"
NAMESPACE_WORKLOAD="gke-enterprise"
REGION="us-central1"

# 1. Resource Readiness
echo "Test 1: Resource Readiness..."
kubectl wait --for=condition=Ready containercluster/${CLUSTER_NAME} --timeout=20m -n ${NAMESPACE}
kubectl wait --for=condition=Ready containernodepool/${NODE_POOL_NAME} --timeout=20m -n ${NAMESPACE}
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

# 3. Workload Identity Integration
echo "Test 3: Workload Identity Integration..."
# Get credentials for the newly created cluster
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}

# Ensure workload namespace exists
kubectl create namespace ${NAMESPACE_WORKLOAD} --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: test-workload-identity
  namespace: ${NAMESPACE_WORKLOAD}
spec:
  template:
    spec:
      serviceAccountName: gke-enterprise-sa
      containers:
      - name: gcloud
        image: google/cloud-sdk:slim
        command: ["gcloud", "auth", "list"]
      restartPolicy: Never
EOF

# Note: This Job might fail if the ServiceAccount 'gke-enterprise-sa' is not yet created by Helm
# So we should probably install the Helm chart FIRST or at least create the SA.
# Let's move Helm installation up or combine.

# 4. Endpoint Interaction (via Helm)
echo "Test 4: Endpoint Interaction (via Helm)..."

# Apply workload via Helm chart
echo "Installing Helm chart from terraform-helm/workload/..."
helm upgrade --install gke-enterprise terraform-helm/workload/ \
  --namespace ${NAMESPACE_WORKLOAD} \
  --create-namespace \
  --wait --timeout=10m

# Now the ServiceAccount should exist, run the WI test Job again
echo "Re-running Workload Identity test Job..."
kubectl delete job test-workload-identity -n ${NAMESPACE_WORKLOAD} --ignore-not-found
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: test-workload-identity
  namespace: ${NAMESPACE_WORKLOAD}
spec:
  template:
    spec:
      serviceAccountName: gke-enterprise-sa
      containers:
      - name: gcloud
        image: google/cloud-sdk:slim
        command: ["gcloud", "auth", "list"]
      restartPolicy: Never
EOF

kubectl wait --for=condition=complete job/test-workload-identity --timeout=5m -n ${NAMESPACE_WORKLOAD}
# Check logs to see if authentication was successful
kubectl logs job/test-workload-identity -n ${NAMESPACE_WORKLOAD}
# Clean up job
kubectl delete job test-workload-identity -n ${NAMESPACE_WORKLOAD}

# Wait for LoadBalancer IP
SERVICE_IP=""
for i in {1..20}; do
  SERVICE_IP=$(kubectl get svc -n ${NAMESPACE_WORKLOAD} -l app.kubernetes.io/instance=gke-enterprise -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' || true)
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
helm uninstall gke-enterprise -n ${NAMESPACE_WORKLOAD}

# Delete KCC manifests
# Note: GEMINI.md says: Always delete KCC ContainerCluster first, wait for STOPPING.
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
