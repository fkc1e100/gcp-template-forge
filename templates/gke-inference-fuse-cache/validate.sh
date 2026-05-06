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

echo "Starting GKE GCS FUSE Inference Cache Validation Tests..."

PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
REGION=${REGION:-"us-central1"}
NAMESPACE=${NAMESPACE:-"default"}
BUCKET_NAME_BASE="gke-inf-fuse-cache"

# 0. Cluster Detection
if [ -z "${CLUSTER_NAME}" ]; then
  echo "CLUSTER_NAME not set, attempting to detect cluster..."
  # Try exact names first
  if gcloud container clusters describe gke-inf-fuse-cache --region ${REGION} --project ${PROJECT_ID} >/dev/null 2>&1; then
    CLUSTER_NAME="gke-inf-fuse-cache"
    echo "Detected Terraform cluster: ${CLUSTER_NAME}"
  elif gcloud container clusters describe gke-inf-fuse-cache-kcc --region ${REGION} --project ${PROJECT_ID} >/dev/null 2>&1; then
    CLUSTER_NAME="gke-inf-fuse-cache-kcc"
    echo "Detected Config Connector cluster: ${CLUSTER_NAME}"
  else
    # Try detecting via list with filter (to handle CI suffixes)
    DETECTED_TF=$(gcloud container clusters list --project ${PROJECT_ID} --filter="name ~ gke-inf-fuse-cache.*-tf" --format="value(name)" --limit 1)
    if [ -n "${DETECTED_TF}" ]; then
      CLUSTER_NAME="${DETECTED_TF}"
      echo "Detected Terraform cluster (suffixed): ${CLUSTER_NAME}"
    else
      DETECTED_KCC=$(gcloud container clusters list --project ${PROJECT_ID} --filter="name ~ gke-inf-fuse-cache.*-kcc" --format="value(name)" --limit 1)
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
TEMPLATE_LABEL="gke-inf-fuse-cache"
if [[ "${CLUSTER_NAME}" == *"-"* ]]; then
  # Try to extract suffix from cluster name (e.g. gke-inf-fuse-cache-123456-tf)
  SUFFIX=$(echo ${CLUSTER_NAME} | grep -oE "[0-9]{6}" || true)
  if [ -n "${SUFFIX}" ]; then
    # Try finding pods with this suffix in their template label
    if kubectl get pods --all-namespaces -l template=${TEMPLATE_LABEL}-${SUFFIX} >/dev/null 2>&1; then
      TEMPLATE_LABEL="gke-inf-fuse-cache-${SUFFIX}"
      echo "Detected unique template label: ${TEMPLATE_LABEL}"
    fi
  fi
fi

# Detect Bucket Name
if [ -z "${BUCKET_NAME}" ]; then
  echo "Attempting to detect bucket..."
  # Try specific names based on cluster type
  if [[ "${CLUSTER_NAME}" == *"-tf" ]]; then
    DETECTED_BUCKET=$(gcloud storage buckets list --project ${PROJECT_ID} --filter="name ~ gke-inf-fuse-cache-tf.*-bucket" --format="value(name)" --limit 1)
  elif [[ "${CLUSTER_NAME}" == *"-kcc" ]]; then
    DETECTED_BUCKET=$(gcloud storage buckets list --project ${PROJECT_ID} --filter="name ~ gke-inf-fuse-cache.*-kcc-bucket" --format="value(name)" --limit 1)
  fi
  
  # Fallback to general detection
  if [ -z "${DETECTED_BUCKET}" ]; then
    DETECTED_BUCKET=$(gcloud storage buckets list --project ${PROJECT_ID} --filter="name ~ ${BUCKET_NAME_BASE}.*-bucket" --format="value(name)" --limit 1)
  fi

  if [ -n "${DETECTED_BUCKET}" ]; then
    BUCKET_NAME="${DETECTED_BUCKET}"
    echo "Detected bucket: ${BUCKET_NAME}"
  else
    echo "WARNING: Could not detect bucket with base name ${BUCKET_NAME_BASE}"
  fi
fi

# Isolate KUBECONFIG
export KUBECONFIG=$(mktemp)
trap 'rm -f "$KUBECONFIG"' EXIT

# 1. Cluster Connectivity
echo "Test 1: Cluster Connectivity..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
kubectl cluster-info
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
  elif kubectl get job stage-model -n ${NAMESPACE} >/dev/null 2>&1; then
    JOB_NAME="stage-model"
  fi
fi

if [ -z "${JOB_NAME}" ]; then
  echo "ERROR: Could not find staging Job."
  exit 1
fi

echo "Waiting for staging Job ${JOB_NAME}..."
kubectl wait --for=condition=complete job/${JOB_NAME} -n ${NAMESPACE} --timeout=30m
echo "Staging Job complete."

echo "Waiting for deployment ${DEPLOY_NAME}..."
kubectl wait --for=condition=available deployment/${DEPLOY_NAME} -n ${NAMESPACE} --timeout=30m
echo "Workload is available."

# 5. Sidecar and Mount Verification
echo "Test 5: Sidecar and Mount Verification..."
# Target the pod from the deployment, avoiding staging jobs
POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=vllm,template=${TEMPLATE_LABEL} -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | awk '{print $1}')

if [ -z "$POD_NAME" ]; then
  echo "ERROR: Could not find a running vLLM pod. Checking all pods with app=vllm:"
  kubectl get pods -n ${NAMESPACE} -l app=vllm
  exit 1
fi

echo "Using pod: ${POD_NAME}"

# Check for gcs-fuse sidecar
# Note: In GKE 1.29+, sidecar containers are a native feature.
# The driver might also inject it as a regular container.
SIDECAR_EXISTS=$(kubectl get pod ${POD_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.containers[*].name}' | grep "gke-gcsfuse-sidecar" || true)
if [ -z "$SIDECAR_EXISTS" ]; then
  # In recent GKE, the sidecar is injected. Let's check initContainers too or just look for the mount
  echo "GCS FUSE Sidecar not found in pod containers. Checking mount point..."
fi

# Check mount point
echo "Checking mount point /models..."
MOUNT_CHECK=$(kubectl exec ${POD_NAME} -n ${NAMESPACE} -c vllm-openai -- df -T /models | grep "fuse" || true)

if [ -z "$MOUNT_CHECK" ]; then
  echo "GCS FUSE mount point /models not found or incorrect type!"
  echo "Debugging information:"
  echo "--- Mounts in pod ---"
  kubectl exec ${POD_NAME} -n ${NAMESPACE} -c vllm-openai -- mount | grep "/models" || echo "/models not found in mount output"
  echo "--- Filesystem types ---"
  kubectl exec ${POD_NAME} -n ${NAMESPACE} -c vllm-openai -- df -T
  exit 1
fi
echo "GCS FUSE mount point /models verified."

# 6. GPU Check
echo "Test 6: GPU Check..."
# Try nvidia-smi first, fallback to checking device file for dummy images (which don't have nvidia-smi in PATH)
# We use sh -c to avoid kubectl exec failing if the binary is missing, and 2>&1 to capture all output.
GPU_CHECK=$(kubectl exec ${POD_NAME} -n ${NAMESPACE} -- sh -c "nvidia-smi -L 2>/dev/null || ls /dev/nvidia0 2>/dev/null" || true)
if [ -z "$GPU_CHECK" ]; then
  echo "NVIDIA GPU not detected in pod!"
  # List /dev to see what is there
  echo "--- Contents of /dev in pod ---"
  kubectl exec ${POD_NAME} -n ${NAMESPACE} -- ls /dev || true
  exit 1
fi
echo "GPU verified: $GPU_CHECK"

# 7. vLLM API Health Check
echo "Test 7: vLLM API Health Check..."
# Wait a bit for vLLM to initialize (it might be slow even after pod is available)
MAX_RETRIES=12
RETRY_COUNT=0
# Use python3 as a robust health check in the dummy image.
# If python3 is missing, fallback to /health check via any available tool.
CHECK_CMD="python3 -c \"import urllib.request; urllib.request.urlopen('http://localhost:8000/health')\" 2>/dev/null || wget -qO- http://localhost:8000/health 2>/dev/null || curl -s http://localhost:8000/health"
until kubectl exec ${POD_NAME} -n ${NAMESPACE} -- sh -c "$CHECK_CMD" >/dev/null 2>&1 || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
  echo "Waiting for vLLM API... ($RETRY_COUNT/$MAX_RETRIES)"
  sleep 15
  RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "vLLM API health check failed after $MAX_RETRIES retries!"
  # Print some logs to help debugging
  kubectl logs ${POD_NAME} -n ${NAMESPACE} --tail=20
  exit 1
fi
echo "vLLM API is healthy."

echo "All GKE GCS FUSE Inference Cache Validation Tests passed successfully!"
