#!/bin/bash
set -e

# This is a minimal validation script that checks the structural integrity of the template.
# In a real CI environment, this would perform deeper checks.

echo "=== Validating k8s-deployer template ==="

echo "Checking directory structure..."
[ -d "terraform-helm" ] || (echo "ERROR: terraform-helm directory missing"; exit 1)
[ -d "config-connector" ] || (echo "ERROR: config-connector directory missing"; exit 1)
[ -d "config-connector-workload" ] || (echo "ERROR: config-connector-workload directory missing"; exit 1)

echo "Validating Terraform configuration..."
cd terraform-helm
terraform init -backend=false
terraform validate
cd ..

echo "Checking README for mandatory headers..."
grep -q "## Architecture" README.md || (echo "ERROR: README.md missing Architecture header"; exit 1)

echo "Validation successful!"
