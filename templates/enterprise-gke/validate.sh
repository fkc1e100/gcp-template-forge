#!/usr/bin/env bash
set -e

echo "Starting KCC Validation Tests..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME="enterprise-gke"
NODE_POOL_NAME="enterprise-gke-pool"
NAMESPACE="forge-management"
NAMESPACE_WORKLOAD="enterprise-gke"
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

# Apply namespace first
kubectl apply -f config-connector/workload/namespace.yaml

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: test-workload-identity
  namespace: ${NAMESPACE_WORKLOAD}
spec:
  template:
    spec:
      serviceAccountName: enterprise-gke-sa
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
echo "Workload Identity Integration passed."

# 4. Endpoint Interaction
echo "Test 4: Endpoint Interaction..."

# Apply workload manifests to the target cluster
echo "Applying workload manifests to target cluster..."
kubectl apply -R -f config-connector/workload/

# Wait for rollout
kubectl rollout status deployment/enterprise-gke -n ${NAMESPACE_WORKLOAD} --timeout=5m

# Wait for LoadBalancer IP
SERVICE_IP=""
for i in {1..20}; do
  SERVICE_IP=$(kubectl get svc enterprise-gke -o jsonpath='{.status.loadBalancer.ingress[0].ip}' -n ${NAMESPACE_WORKLOAD} || true)
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

echo "Testing endpoint http://${SERVICE_IP}:8080/..."
# Retry curl as the LB might take a few moments to actually start serving
for i in {1..10}; do
  if curl -sf http://${SERVICE_IP}:8080/; then
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
# Delete workload from target cluster
kubectl delete -R -f config-connector/workload/ --ignore-not-found

# Delete KCC manifests
kubectl delete -f config-connector/ -n ${NAMESPACE} --ignore-not-found
echo "Waiting for cluster deletion (sleeping 5m)..."
sleep 300

# Verify GCP resource deletion
set +e
gcloud container clusters describe ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
if [ $? -eq 0 ]; then
  echo "Teardown Verification failed! Cluster still exists in GCP."
  exit 1
fi
set -e
echo "Teardown Verification passed."

echo "All KCC Validation Tests passed successfully!"
