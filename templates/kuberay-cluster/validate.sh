#!/bin/bash
set -e
echo "Running Terraform Lint..."
cd terraform
terraform init -backend=false
terraform validate
cd ..
echo "All checks passed!"
