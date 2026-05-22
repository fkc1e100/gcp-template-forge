#!/usr/bin/env bash
set -eo pipefail

echo "=== START WORKLOAD VALIDATION ==="

# 1. Fetch GKE cluster credentials
echo "Configuring kubectl..."
gcloud container clusters get-credentials "${TF_VAR_cluster_name}" --zone "${TF_VAR_zone}" --project "${TF_VAR_project_id}"

# 2. Wait for deployment to be ready
echo "Waiting for Deployment to be ready..."
kubectl rollout status deployment/hello-custom-compute -n default --timeout=300s

# 3. Verify Pods are scheduled on the custom compute node pool
echo "Verifying node labels of running pods..."
NODE_NAME=$(kubectl get pods -l app=hello-custom-compute -o jsonpath='{.items[0].spec.nodeName}')
WORKLOAD_TYPE=$(kubectl get node "${NODE_NAME}" -o jsonpath='{.metadata.labels.workload-type}')

if [ "${WORKLOAD_TYPE}" != "custom-compute" ]; then
  echo "FAIL: Pod was scheduled on node ${NODE_NAME} with label workload-type=${WORKLOAD_TYPE}, expected workload-type=custom-compute"
  exit 1
fi
echo "SUCCESS: Pod is correctly running on a custom-compute node!"

# 4. Wait for external IP of the Service and check health
echo "Waiting for Service LoadBalancer external IP..."
LB_IP=""
for i in {1..30}; do
  LB_IP=$(kubectl get svc hello-custom-compute -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [ -n "${LB_IP}" ]; then
    break
  fi
  echo "Waiting for External IP (attempt $i/30)..."
  sleep 10
done

if [ -z "${LB_IP}" ]; then
  echo "LoadBalancer IP not provisioned in time. Using kubectl port-forward fallback..."
  # Start port-forward in the background
  kubectl port-forward svc/hello-custom-compute 8080:80 &
  PF_PID=$!
  trap "kill ${PF_PID} 2>/dev/null || true" EXIT
  sleep 5
  
  echo "Curling local port-forward endpoint..."
  RESPONSE=$(curl -s -f http://127.0.0.1:8080/ || true)
  if [[ "${RESPONSE}" == *"Welcome"* || "${RESPONSE}" == *"nginx"* ]]; then
    echo "SUCCESS: Web server verified via port-forward fallback!"
  else
    echo "FAIL: Unexpected or empty response from web server over port-forward: ${RESPONSE}"
    exit 1
  fi
else
  echo "Found External IP: ${LB_IP}"
  echo "Curling LB External IP..."
  RESPONSE=""
  for i in {1..10}; do
    RESPONSE=$(curl -s -f "http://${LB_IP}/" || true)
    if [[ "${RESPONSE}" == *"Welcome"* || "${RESPONSE}" == *"nginx"* ]]; then
      break
    fi
    echo "Waiting for connection to external IP (attempt $i/10)..."
    sleep 5
  done

  if [[ "${RESPONSE}" == *"Welcome"* || "${RESPONSE}" == *"nginx"* ]]; then
    echo "SUCCESS: Web server verified via LoadBalancer IP!"
  else
    echo "FAIL: Could not successfully query HTTP endpoint on ${LB_IP}"
    exit 1
  fi
fi

echo "=== WORKLOAD VALIDATION SUCCESSFUL ==="
exit 0
