#!/bin/bash
set -e

PROJECT_ID="gca-gke-2025"
CLUSTER_NAME="enterprise-cluster"
REGION="us-central1"

echo "Step 1: Resource Readiness Test"
kubectl wait --for=condition=Ready containercluster/$CLUSTER_NAME --timeout=20m
kubectl wait --for=condition=Ready containernodepool/primary-pool --timeout=15m
kubectl wait --for=condition=Ready secretmanagersecret/app-secret --timeout=5m

echo "Step 2: Deployment Readiness"
# Get credentials for the new cluster
gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT_ID

echo "Step 3: Workload Identity Integration Test"
# Deploy a temporary job to verify secret access via CSI driver
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: workload-identity-test
spec:
  template:
    spec:
      serviceAccountName: enterprise-workload-sa
      containers:
      - name: test
        image: google/cloud-sdk:slim
        command: ["/bin/bash", "-c"]
        args:
          - |
            echo "Waiting for secret to be mounted..."
            sleep 10
            if [ -f /mnt/secrets/db-password ]; then
              echo "SUCCESS: Secret is accessible via CSI driver."
            else
              echo "FAILURE: Secret not found at /mnt/secrets/db-password."
              exit 1
            fi
        volumeMounts:
        - name: secrets-store-inline
          mountPath: "/mnt/secrets"
          readOnly: true
      restartPolicy: Never
      volumes:
      - name: secrets-store-inline
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "enterprise-secrets"
  backoffLimit: 1
EOF

kubectl wait --for=condition=complete job/workload-identity-test --timeout=5m

echo "Step 4: Drift & Revert Test"
# Out-of-band change: Add a label to the secret via gcloud
gcloud secrets update app-secret --update-labels="drift=true" --project $PROJECT_ID
echo "Waiting for KCC to reconcile..."
sleep 60
# Verify that KCC reverted the label (it should be gone as it's not in the manifest)
LABELS=$(gcloud secrets describe app-secret --project $PROJECT_ID --format="value(labels)")
if [[ $LABELS == *"drift=true"* ]]; then
  echo "FAILURE: KCC did not revert the drift."
  exit 1
else
  echo "SUCCESS: KCC successfully reverted the out-of-band change."
fi

echo "All validation tests passed!"
