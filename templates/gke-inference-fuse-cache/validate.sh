#!/usr/bin/env bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

echo "Starting GKE Inference FUSE Cache Validation Tests..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
REGION=${REGION:-"us-central1"}
NAMESPACE=${NAMESPACE:-"default"}
BUCKET_NAME_BASE="gke-inference-fuse-cache"

# Isolate KUBECONFIG
export KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# Helper for debugging failures
debug_failure() {
  local msg=$1
  echo "Error: $msg"
  echo "=== Debug Info: Nodes ==="
  kubectl get nodes
  echo "=== Debug Info: Pods (all) ==="
  kubectl get pods -A
  echo "=== Debug Info: Events (all) ==="
  kubectl get events -A --sort-by='.lastTimestamp' | tail -n 50
  
  # Try to find the staging job pod
  local STAGING_POD=$(kubectl get pods -n ${NAMESPACE} -l component=staging -o name 2>/dev/null | head -n 1)
  if [ -n "${STAGING_POD}" ]; then
    echo "=== Debug Info: Staging Pod Describe (${STAGING_POD}) ==="
    kubectl describe ${STAGING_POD} -n ${NAMESPACE}
    echo "=== Debug Info: Staging Pod Logs (${STAGING_POD}) ==="
    kubectl logs ${STAGING_POD} -n ${NAMESPACE} || echo "Could not fetch logs"
  fi

  # Try to find the vllm pod
  local VLLM_POD=$(kubectl get pods -n ${NAMESPACE} -l app=vllm -o name 2>/dev/null | head -n 1)
  if [ -n "${VLLM_POD}" ]; then
    echo "=== Debug Info: vLLM Pod Describe (${VLLM_POD}) ==="
    kubectl describe ${VLLM_POD} -n ${NAMESPACE}
    echo "=== Debug Info: vLLM Pod Logs (${VLLM_POD}) ==="
    kubectl logs ${VLLM_POD} -n ${NAMESPACE} -c vllm-openai --tail=100 || echo "Could not fetch logs"
  fi
  
  exit 1
}

# 0. Cluster Detection
if [ -z "${CLUSTER_NAME}" ]; then
  echo "CLUSTER_NAME not set, attempting to detect cluster..."
  # Try exact names first
  if gcloud container clusters describe gke-inference-fuse-cache --region ${REGION} --project ${PROJECT_ID} >/dev/null 2>&1; then
    CLUSTER_NAME="gke-inference-fuse-cache"
    echo "Detected Terraform cluster: ${CLUSTER_NAME}"
  elif gcloud container clusters describe gke-inference-fuse-cache-kcc --region ${REGION} --project ${PROJECT_ID} >/dev/null 2>&1; then
    CLUSTER_NAME="gke-inference-fuse-cache-kcc"
    echo "Detected Config Connector cluster: ${CLUSTER_NAME}"
  else
    # Try detecting via list with filter (to handle CI suffixes)
    DETECTED_TF=$(gcloud container clusters list --project ${PROJECT_ID} --filter="name ~ gke-inference-fuse-cache.*-tf OR name ~ gke-inf-fuse-cache.*-tf" --format="value(name)" --limit 1)
    if [ -n "${DETECTED_TF}" ]; then
      CLUSTER_NAME="${DETECTED_TF}"
      echo "Detected Terraform cluster (suffixed): ${CLUSTER_NAME}"
    else
      DETECTED_KCC=$(gcloud container clusters list --project ${PROJECT_ID} --filter="name ~ gke-inference-fuse-cache.*-kcc OR name ~ gke-inf-fuse-cache.*-kcc" --format="value(name)" --limit 1)
      if [ -n "${DETECTED_KCC}" ]; then
        CLUSTER_NAME="${DETECTED_KCC}"
        echo "Detected Config Connector cluster (suffixed): ${CLUSTER_NAME}"
      fi
    fi
  fi

  if [ -z "${CLUSTER_NAME}" ]; then
    echo "ERROR: Could not detect GKE cluster."
    exit 1
  fi
fi

# 0a. Template Label Detection
# Detect the unique template label used for this run (to handle CI suffixes)
TEMPLATE_LABEL="gke-inference-fuse-cache"
SUFFIX=""

if [[ "${CLUSTER_NAME}" == *"-"* ]]; then
  # Try to extract suffix from cluster name (e.g. gke-inf-fuse-cache-123456-tf)
  SUFFIX=$(echo ${CLUSTER_NAME} | grep -oE "[0-9]{6}" || true)
  if [ -n "${SUFFIX}" ]; then
    TEMPLATE_LABEL="${TEMPLATE_LABEL}-${SUFFIX}"
    echo "Detected unique template label: ${TEMPLATE_LABEL}"
  fi
fi

# Detect Bucket Name
if [ -z "${BUCKET_NAME}" ]; then
  echo "Attempting to detect bucket..."
  # Prefer bucket matching the unique suffix if available
  if [ -n "${SUFFIX}" ]; then
    BUCKET_NAME=$(gcloud storage buckets list --project ${PROJECT_ID} --filter="name ~ .*${SUFFIX}.*" --format="value(name)" --limit 1)
  fi
  
  if [ -z "${BUCKET_NAME}" ]; then
    # Fallback to general detection
    if [[ "${CLUSTER_NAME}" == *"-tf" ]]; then
      BUCKET_NAME=$(gcloud storage buckets list --project ${PROJECT_ID} --filter="name ~ gke-inference-fuse-cache-tf.*-bucket OR name ~ gke-inf-fuse-cache-tf.*-bucket" --format="value(name)" --limit 1)
    elif [[ "${CLUSTER_NAME}" == *"-kcc" ]]; then
      BUCKET_NAME=$(gcloud storage buckets list --project ${PROJECT_ID} --filter="name ~ gke-inference-fuse-cache.*-kcc-bucket OR name ~ gke-inf-fuse-cache.*-kcc-bucket" --format="value(name)" --limit 1)
    fi
  fi
  
  if [ -z "${BUCKET_NAME}" ]; then
    BUCKET_NAME=$(gcloud storage buckets list --project ${PROJECT_ID} --filter="name ~ ${BUCKET_NAME_BASE}.*-bucket OR name ~ gke-inf-fuse-cache.*-bucket" --format="value(name)" --limit 1)
  fi

  if [ -n "${BUCKET_NAME}" ]; then
    echo "Detected bucket: ${BUCKET_NAME}"
  else
    echo "WARNING: Could not detect bucket with base name ${BUCKET_NAME_BASE}"
  fi
fi

# 1. Cluster Connectivity
echo "Test 1: Cluster Connectivity..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
kubectl cluster-info || debug_failure "Failed to connect to cluster"
echo "Connectivity passed."

# 2. GCS FUSE CSI Driver Check
echo "Test 2: GCS FUSE CSI Driver Check..."
GCS_FUSE_ENABLED=$(gcloud container clusters describe ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID} --format="value(addonsConfig.gcsFuseCsiDriverConfig.enabled)")
if [ "$GCS_FUSE_ENABLED" != "True" ]; then
  echo "GCS FUSE CSI Driver is not enabled!"
  exit 1
fi
echo "GCS FUSE CSI Driver is enabled."

# 3. Node Pool Local SSD Check
echo "Test 3: Node Pool Local SSD Check..."
# Detect pool name (prefer GPU pool)
POOL_NAME=$(gcloud container node-pools list --cluster ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID} --format="value(name)" | grep "gpu" | head -n 1)
if [ -z "$POOL_NAME" ]; then
  POOL_NAME=$(gcloud container node-pools list --cluster ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID} --format="value(name)" | grep "pool" | head -n 1)
fi
SSD_COUNT=$(gcloud container node-pools describe ${POOL_NAME} --cluster ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID} --format="value(config.ephemeralStorageLocalSsdConfig.localSsdCount)")
if [ "$SSD_COUNT" -lt 1 ]; then
  echo "Node pool does not have Local SSDs for caching!"
  exit 1
fi
echo "Node pool has $SSD_COUNT Local SSD(s) for caching."

# 4. Workload Readiness
echo "Test 4: Workload Readiness..."
DEPLOY_NAME="vllm-inference"

# Detect Job name using label
JOB_NAME=$(kubectl get job -n ${NAMESPACE} -l component=staging,template=${TEMPLATE_LABEL} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "${JOB_NAME}" ]; then
  echo "WARNING: Could not detect Job with label component=staging,template=${TEMPLATE_LABEL}, falling back to names..."
  if kubectl get job release-vllm-inference-stage -n ${NAMESPACE} >/dev/null 2>&1; then
    JOB_NAME="release-vllm-inference-stage"
  elif kubectl get job vllm-inference-stage -n ${NAMESPACE} >/dev/null 2>&1; then
    JOB_NAME="vllm-inference-stage"
  fi
fi

if [ -z "${JOB_NAME}" ]; then
  echo "ERROR: Could not find staging Job."
  exit 1
fi

echo "Waiting for staging Job ${JOB_NAME}..."
# Wait for the job to start its pod first
RETRY=0
while [ $RETRY -lt 10 ]; do
  POD_PHASE=$(kubectl get pods -n ${NAMESPACE} -l component=staging -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
  echo "Staging pod phase: ${POD_PHASE}"
  if [ "${POD_PHASE}" == "Running" ] || [ "${POD_PHASE}" == "Succeeded" ] || [ "${POD_PHASE}" == "Failed" ]; then
    break
  fi
  if [ "${POD_PHASE}" == "Pending" ]; then
    echo "Staging pod is Pending, checking for events..."
    kubectl get events -n ${NAMESPACE} --field-selector involvedObject.kind=Pod | grep -i staging || true
  fi
  sleep 30
  RETRY=$((RETRY+1))
done

# Now wait for completion with a long timeout
kubectl wait --for=condition=complete job/${JOB_NAME} -n ${NAMESPACE} --timeout=120m || {
  echo "Staging Job did not complete successfully. Checking status..."
  kubectl get job ${JOB_NAME} -n ${NAMESPACE} -o yaml
  debug_failure "Staging Job failed or timed out"
}
echo "Staging Job complete."

echo "Waiting for deployment ${DEPLOY_NAME}..."
kubectl wait --for=condition=available deployment/${DEPLOY_NAME} -n ${NAMESPACE} --timeout=60m || debug_failure "Deployment failed to become available"
echo "Workload is available."

# 5. Sidecar and Mount Verification
echo "Test 5: Sidecar and Mount Verification..."
# Target the pod from the deployment, avoiding staging jobs
POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=vllm,template=${TEMPLATE_LABEL} -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | awk '{print $1}')

if [ -z "$POD_NAME" ]; then
  debug_failure "Could not find a running vLLM pod"
fi

echo "Using pod: ${POD_NAME}"

# Check mount point
echo "Checking mount point /models..."
MOUNT_CHECK=$(kubectl exec ${POD_NAME} -n ${NAMESPACE} -c vllm-openai -- df -T /models | grep "fuse" || true)

if [ -z "$MOUNT_CHECK" ]; then
  debug_failure "GCS FUSE mount point /models not found or incorrect type"
fi
echo "GCS FUSE mount point /models verified."

# 6. Resource Isolation and Security Verification
echo "Test 6: Resource Isolation and Security Verification..."
kubectl get resourcequota -n ${NAMESPACE} -l template=${TEMPLATE_LABEL} >/dev/null 2>&1 || debug_failure "ResourceQuota missing"
kubectl get limitrange -n ${NAMESPACE} -l template=${TEMPLATE_LABEL} >/dev/null 2>&1 || debug_failure "LimitRange missing"
kubectl get networkpolicy -n ${NAMESPACE} -l template=${TEMPLATE_LABEL} >/dev/null 2>&1 || debug_failure "NetworkPolicy missing"
echo "Resource isolation and security verified."

# 7. GPU Check
echo "Test 7: GPU Check..."
GPU_CHECK=$(kubectl exec ${POD_NAME} -n ${NAMESPACE} -- sh -c "nvidia-smi -L 2>/dev/null || ls /dev/nvidia0 2>/dev/null" || true)
if [ -z "$GPU_CHECK" ]; then
  debug_failure "NVIDIA GPU not detected in pod"
fi
echo "GPU verified: $GPU_CHECK"

# 8. vLLM API Health Check
echo "Test 8: vLLM API Health Check..."
MAX_RETRIES=20
RETRY_COUNT=0
CHECK_CMD="python3 -c \"import urllib.request; urllib.request.urlopen('http://localhost:8000/health')\" 2>/dev/null || wget -qO- http://localhost:8000/health 2>/dev/null || curl -s http://localhost:8000/health"
until kubectl exec ${POD_NAME} -n ${NAMESPACE} -- sh -c "$CHECK_CMD" >/dev/null 2>&1 || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
  echo "Waiting for vLLM API... ($RETRY_COUNT/$MAX_RETRIES)"
  sleep 15
  RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  debug_failure "vLLM API health check failed after $MAX_RETRIES retries"
fi
echo "vLLM API is healthy."

echo "All GKE Inference FUSE Cache Validation Tests passed successfully!"
