#!/bin/bash
set -e
echo "Validating Kubernetes manifests..."
kubectl apply --dry-run=client -f manifests/
echo "Validation successful."
