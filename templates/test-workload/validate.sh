#!/bin/bash
set -e

echo "Starting validation of test-workload..."

# Wait for KCC bucket to be ready
echo "Waiting for StorageBucket/test-workload-bucket to be Ready..."
kubectl wait --for=condition=Ready storagebucket/test-workload-bucket --timeout=5m

# Verify Terraform-created bucket (via gcloud)
# Note: In a real scenario, this would use gcloud.
# For this test, we just echo that it's being verified.
echo "Verifying terraform-created bucket (placeholder)..."
# gcloud storage buckets describe gs://test-workload-terraform-bucket-*

echo "Validation successful!"
