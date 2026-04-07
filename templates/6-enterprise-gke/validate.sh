#!/usr/bin/env bash
set -e

echo "Starting KCC Validation Tests..."

# Assuming PROJECT_ID and CLUSTER_NAME are set by the pipeline
PROJECT_ID=${PROJECT_ID:-"YOUR_PROJECT_ID"}
CLUSTER_NAME=${CLUSTER_NAME:-"enterprise-cluster"}
NODE_POOL_NAME="enterprise-pool"

# 1. Resource Readiness
echo "Test 1: Resource Readiness..."
kubectl wait --for=condition=Ready containercluster/${CLUSTER_NAME} --timeout=20m -n default
kubectl wait --for=condition=Ready containernodepool/${NODE_POOL_NAME} --timeout=20m -n default
echo "Resource Readiness passed."

# 2. Drift & Revert
echo "Test 2: Drift & Revert..."
# Make an out-of-band change using gcloud (e.g. adding a label to the cluster)
gcloud container clusters update ${CLUSTER_NAME} --region us-central1 --update-labels drift=test --project ${PROJECT_ID}
echo "Out-of-band change applied. Waiting for KCC to revert (sleeping 3m)..."
sleep 180
# Verify the label is removed by KCC
LABELS=$(gcloud container clusters describe ${CLUSTER_NAME} --region us-central1 --project ${PROJECT_ID} --format="value(resourceLabels.drift)")
if [ ! -z "$LABELS" ]; then
  echo "Drift Revert failed! KCC did not revert the change."
  exit 1
fi
echo "Drift & Revert passed."

# 3. Workload Identity Integration
echo "Test 3: Workload Identity Integration..."
# For testing Workload Identity, we deploy a lightweight pod to check if it can authenticate.
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: test-workload-identity
  namespace: default
spec:
  template:
    spec:
      serviceAccountName: default # Should be bound to a GCP SA if configured
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
# Delete KCC manifests
kubectl delete -f cluster/
echo "Waiting for cluster deletion (sleeping 5m)..."
sleep 300

# Verify GCP resource deletion
set +e
gcloud container clusters describe ${CLUSTER_NAME} --region us-central1 --project ${PROJECT_ID}
if [ $? -eq 0 ]; then
  echo "Teardown Verification failed! Cluster still exists in GCP."
  exit 1
fi
set -e
echo "Teardown Verification passed."

echo "All KCC Validation Tests passed successfully!"
