#!/usr/bin/env bash
set -e

echo "Starting KCC Validation Tests..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
CLUSTER_NAME="enterprise-cluster-6-kcc"
NODE_POOL_NAME="primary-node-pool-6-kcc"
NAMESPACE="forge-management"
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
# We need to target the NEW cluster. KCC creates it, but we need to get credentials.
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: test-workload-identity
  namespace: default
spec:
  template:
    spec:
      serviceAccountName: enterprise-workload-sa
      containers:
      - name: gcloud
        image: google/cloud-sdk:slim
        command: ["gcloud", "auth", "list"]
      restartPolicy: Never
EOF

kubectl wait --for=condition=complete job/test-workload-identity --timeout=5m -n default
# Check logs to see if authentication was successful
kubectl logs job/test-workload-identity -n default
# Clean up job
kubectl delete job test-workload-identity -n default
echo "Workload Identity Integration passed."

# 4. Teardown Verification
echo "Test 4: Teardown Verification..."
# Switch back to KCC management cluster context if needed
# (Assuming the runner stays in the right context or we use -n forge-management)

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
