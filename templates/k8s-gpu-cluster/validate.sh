#!/bin/bash
# This script runs inside the cluster to verify GPU availability
echo "Checking for GPU... (this may take a minute for pod to schedule)"
for i in {1..30}; do
  RESULT=$(kubectl logs gpu-test-pod 2>&1 | grep "NVIDIA-SMI")
  if [ ! -z "$RESULT" ]; then
    echo "SUCCESS: GPU detected!"
    echo "$RESULT"
    exit 0
  fi
  sleep 5
done

echo "FAILURE: GPU not detected or pod failed to run."
exit 1
