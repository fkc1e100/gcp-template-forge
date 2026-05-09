#!/bin/bash
set -e

echo "Running validation for k8s-service-deployment..."

# 1. Check Terraform structure
if [ ! -d "terraform" ]; then
  echo "Error: terraform directory missing"
  exit 1
fi

# 2. Check Kubernetes manifests
if [ ! -f "kubernetes/deployment.yaml" ]; then
  echo "Error: kubernetes/deployment.yaml missing"
  exit 1
fi

# 3. Check for LoadBalancer service presence
if ! grep -q "type: LoadBalancer" kubernetes/deployment.yaml; then
  echo "Error: Deployment must include a LoadBalancer service"
  exit 1
fi

echo "Validation Passed!"
