#!/usr/bin/env bash
set -eo pipefail

echo "===================================================="
echo "Starting Validation for gke-custom-compute-c"
echo "===================================================="

# Helper function to log messages
log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1"
}

# 1. Get Cluster Credentials
log "Getting credentials for cluster ${TF_VAR_cluster_name}..."
gcloud container clusters get-credentials "${TF_VAR_cluster_name}"   --zone "${TF_VAR_zone:-us-central1-a}"   --project "${TF_VAR_project_id}"

# 2. Extract Deployment and Service names dynamically from the cluster
log "Finding service and deployment names..."
DEPLOYMENT_NAME=$(kubectl get deployment -o jsonpath='{.items[...metadata.name]}' | tr ' ' '\n' | grep "workload$" | head -n 1)
if [ -z "$DEPLOYMENT_NAME" ]; then
  DEPLOYMENT_NAME="workload-workload"
fi

SERVICE_NAME=$(kubectl get service -o jsonpath='{.items[...metadata.name]}' | tr ' ' '\n' | grep "service$" | head -n 1)
if [ -z "$SERVICE_NAME" ]; then
  SERVICE_NAME="workload-service"
fi

# 3. Wait for Deployment to become Available
log "Waiting for Deployment ${DEPLOYMENT_NAME} to become available..."
kubectl wait --for=condition=available deployment/"${DEPLOYMENT_NAME}" --timeout=300s

# 4. Find replica Pod
POD_NAME=$(kubectl get pods -l app="${DEPLOYMENT_NAME}" -o jsonpath='{.items[0].metadata.name}')
log "Using Pod: ${POD_NAME} to verify Service: ${SERVICE_NAME}"

# 5. Perform Functional Verification (Curl service internally from within a pod)
log "Running curl test inside the cluster to verify HTTP traffic..."
MAX_ATTEMPTS=12
ATTEMPT=1
SUCCESS=false

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
  log "Attempt $ATTEMPT/$MAX_ATTEMPTS: Curling internal service..."
  if kubectl exec "${POD_NAME}" -- curl -sSf "http://${SERVICE_NAME}" > /dev/null; then
    log "SUCCESS: Workload is serving HTTP requests correctly!"
    SUCCESS=true
    break
  else
    log "Service not reachable yet. Retrying in 10 seconds..."
    sleep 10
    ATTEMPT=$((ATTEMPT + 1))
  fi
done

if [ "$SUCCESS" = false ]; then
  log "ERROR: Workload functional verification failed after $MAX_ATTEMPTS attempts."
  exit 1
fi

log "Retrieving service status for reference:"
kubectl get svc "${SERVICE_NAME}" -o wide

echo "===================================================="
echo "Validation Successful!"
echo "===================================================="
