#!/bin/bash
set -e
echo "Validating Terraform..."
cd terraform && terraform init -backend=false
terraform validate
echo "Validation successful!"
