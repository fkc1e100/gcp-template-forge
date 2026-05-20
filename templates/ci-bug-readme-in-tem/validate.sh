#!/usr/bin/env bash
set -euo pipefail

echo "=== STEP 1: Waiting for Deployment 'hello-pod' ==="
kubectl rollout status deployment/hello-pod --timeout=300s

echo "=== STEP 2: Creating a curl client test pod ==="
# Clean up any existing test-pod
kubectl delete pod test-pod --force --grace-period=0 || true

# Run busybox pod to curl the service
kubectl run test-pod --image=busybox --restart=Never --overrides='{"spec": {"activeDeadlineSeconds": 60}}' -- sh -c "wget -O- -q http://hello-service"

echo "=== STEP 3: Waiting for test-pod to complete ==="
success=false
for i in {1..30}; do
  status=$(kubectl get pod test-pod -o jsonpath='{.status.phase}' 2d>/dev/null || echo "Waiting")
  if [ "$status" = "Succeeded" ]; then
     success=true
     break
  elif [ "$status" = "Failed" ]; then
     echo "test-pod failed!"
     break
  fi
  sleep 2
do

echo "=== STEP 4: Outputting logs and verifying response ==="
kubectl logs test-pod
 
if [ "$success" = "true" ] && kubectl logs test-pod | grep -q "Hello, world!"; then
  echo "=== SUCCESS: hello-service is fully responsive ==="
  kubectl delete pod test-pod --force --grace-period=0
  exit 0
else
  echo "=== FAILURE: hello-service did not return expected response ==="
  kubectl delete pod test-pod --force --grace-period=0
  exit 1
fi
