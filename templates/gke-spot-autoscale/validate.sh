#!/bin/bash
set -e
echo "Running validation for GKE Spot Autoscale template..."
# Check if terraform files exist
[ -f terraform/main.tf ] || { echo "terraform/main.tf missing"; exit 1; }
[ -f deployment.yaml ] || { echo "deployment.yaml missing"; exit 1; }
# Check for spot flag in deployment
grep -q "cloud.google.com/gke-spot: \"true\"" deployment.yaml || { echo "Spot nodeSelector missing"; exit 1; }
echo "Validation passed!"
