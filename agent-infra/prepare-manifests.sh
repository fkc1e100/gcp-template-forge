#!/bin/bash
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

TEMPLATE_PATH=$1
UID_SUFFIX=$2

if [ -z "$TEMPLATE_PATH" ] || [ -z "$UID_SUFFIX" ]; then
  echo "Usage: $0 <template_path> <uid_suffix>"
  exit 1
fi

FULL_NAME=$(basename "$TEMPLATE_PATH")
PROJECT_ID=${PROJECT_ID:-"gca-gke-2025"}
SHARED_SA="forge-builder@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Suffixing manifests for $FULL_NAME with $UID_SUFFIX"

# 1. Suffix based on full template name (Standard)
find "${TEMPLATE_PATH}/config-connector" "${TEMPLATE_PATH}/config-connector-workload" -type f -name "*.yaml" -exec sed -i "s/${FULL_NAME}/${FULL_NAME}-${UID_SUFFIX}/g" {} + 2>/dev/null || true

# 2. Special cases for shortened resource names to avoid GCP limits (30 chars for GSAs)
if [[ "$FULL_NAME" == "gke-inference-fuse-cache" ]]; then
  echo "Applying special suffixing for gke-inference-fuse-cache"
  find "${TEMPLATE_PATH}/config-connector" "${TEMPLATE_PATH}/config-connector-workload" -type f -name "*.yaml" -exec sed -i "s/gke-inf-fuse-node/gke-inf-fuse-node-${UID_SUFFIX}/g" {} + 2>/dev/null || true
  find "${TEMPLATE_PATH}/config-connector" "${TEMPLATE_PATH}/config-connector-workload" -type f -name "*.yaml" -exec sed -i "s/gke-inf-fuse-cache/gke-inf-fuse-cache-${UID_SUFFIX}/g" {} + 2>/dev/null || true
  find "${TEMPLATE_PATH}/config-connector" "${TEMPLATE_PATH}/config-connector-workload" -type f -name "*.yaml" -exec sed -i "s/gke-inf-fuse-workload/gke-inf-fuse-workload-${UID_SUFFIX}/g" {} + 2>/dev/null || true
fi

if [[ "$FULL_NAME" == "gke-kuberay-kueue-multitenant" ]]; then
  echo "Applying special suffixing for gke-kuberay-kueue-multitenant"
  find "${TEMPLATE_PATH}/config-connector" "${TEMPLATE_PATH}/config-connector-workload" -type f -name "*.yaml" -exec sed -i "s/gke-ray-mt-node/gke-ray-mt-node-${UID_SUFFIX}/g" {} + 2>/dev/null || true
fi

# 3. CI-specific Patching for projects with restricted IAM permissions
if [[ "$PROJECT_ID" == "gca-gke-2025" ]]; then
  echo "Detected CI environment, applying IAM and values.yaml workarounds..."
  
  # Patch placeholders in all YAML manifests
  find "${TEMPLATE_PATH}/config-connector" "${TEMPLATE_PATH}/config-connector-workload" -type f -name "*.yaml" -exec sed -i "s/<PROJECT_ID>/${PROJECT_ID}/g" {} + 2>/dev/null || true
  find "${TEMPLATE_PATH}/config-connector" "${TEMPLATE_PATH}/config-connector-workload" -type f -name "*.yaml" -exec sed -i "s/<REGION>/${REGION:-us-central1}/g" {} + 2>/dev/null || true
  
  # Predict/Detect bucket name
  # The inference template uses <BUCKET_NAME>
  # KCC path: gke-inf-fuse-cache-kcc-bucket -> gke-inf-fuse-cache-${UID_SUFFIX}-kcc-bucket (after standard suffixing)
  # TF path: gke-inf-fuse-cache-tf-${UID_SUFFIX}-bucket
  BUCKET_NAME="gke-inf-fuse-cache-tf-${UID_SUFFIX}-bucket"
  
  # Try to detect if it already exists (might be different if not using standard naming)
  EXISTING_BUCKET=$(gcloud storage buckets list --project ${PROJECT_ID} --filter="name ~ .*${UID_SUFFIX}.*" --format="value(name)" --limit 1 2>/dev/null || echo "")
  if [ -n "$EXISTING_BUCKET" ]; then
    BUCKET_NAME="$EXISTING_BUCKET"
  fi
  
  find "${TEMPLATE_PATH}/config-connector" "${TEMPLATE_PATH}/config-connector-workload" -type f -name "*.yaml" -exec sed -i "s/<BUCKET_NAME>/${BUCKET_NAME}/g" {} + 2>/dev/null || true

  # Patch values.yaml if it exists
  VALUES_PATH="${TEMPLATE_PATH}/terraform-helm/workload/values.yaml"
  if [ -f "$VALUES_PATH" ]; then
    echo "Patching $VALUES_PATH for CI"
    sed -i "s/<PROJECT_ID>/${PROJECT_ID}/g" "$VALUES_PATH"
    sed -i "s/<REGION>/${REGION:-us-central1}/g" "$VALUES_PATH"
    sed -i "s/<CLUSTER_NAME>/${FULL_NAME}-${UID_SUFFIX}-tf/g" "$VALUES_PATH"
    sed -i "s/uidSuffix: \"\"/uidSuffix: \"${UID_SUFFIX}\"/g" "$VALUES_PATH"
    # Template specific value patches
    sed -i "s/bucketName: \"\"/bucketName: \"gke-inf-fuse-cache-tf-${UID_SUFFIX}-bucket\"/g" "$VALUES_PATH"
  fi

  # Use Python for robust YAML patching of KCC manifests
  python3 - <<EOF
import yaml
import sys
import pathlib

shared_sa = "${SHARED_SA}"
project_id = "${PROJECT_ID}"

def patch_doc(doc):
    if not isinstance(doc, dict):
        return doc
    
    # 1. Remove IAMServiceAccount and other restricted resources
    if doc.get("kind") in ["IAMServiceAccount", "IAMPolicy", "IAMPartialPolicy"]:
        return None
        
    # 2. Remove Workload Identity annotations from ServiceAccounts
    if doc.get("kind") == "ServiceAccount":
        metadata = doc.get("metadata", {})
        annotations = metadata.get("annotations", {})
        if "iam.gke.io/gcp-service-account" in annotations:
            print(f"Removing WI annotation from {metadata.get('name')}")
            del annotations["iam.gke.io/gcp-service-account"]
            if not annotations:
                del metadata["annotations"]

    # 3. Handle IAMPolicyMember specially
    if doc.get("kind") == "IAMPolicyMember":
        spec = doc.get("spec", {})
        if "memberFrom" in spec:
            print(f"Converting memberFrom to member in IAMPolicyMember {doc.get('metadata', {}).get('name')}")
            del spec["memberFrom"]
            spec["member"] = f"serviceAccount:{shared_sa}"
            
        member = spec.get("member", "")
        if member.startswith("serviceAccount:") and project_id in member:
            spec["member"] = f"serviceAccount:{shared_sa}"

    # 4. Replace serviceAccountRef in all other places
    def walk(obj):
        if isinstance(obj, dict):
            if "serviceAccountRef" in obj and isinstance(obj["serviceAccountRef"], dict):
                obj["serviceAccountRef"] = {"external": shared_sa}
            for v in obj.values():
                walk(v)
        elif isinstance(obj, list):
            for i in obj:
                walk(i)

    walk(doc)
    return doc

# Patch BOTH config-connector and config-connector-workload
for dir_name in ["config-connector", "config-connector-workload"]:
    for p in pathlib.Path(f"${TEMPLATE_PATH}/{dir_name}").rglob("*.yaml"):
        if not p.is_file(): continue
        with open(p, "r") as f:
            try:
                docs = list(yaml.safe_load_all(f))
            except yaml.YAMLError:
                continue
        
        new_docs = [patch_doc(d) for d in docs]
        new_docs = [d for d in new_docs if d is not None]
        
        if len(new_docs) > 0:
            print(f"Patching {p} for CI workarounds")
            with open(p, "w") as f:
                yaml.safe_dump_all(new_docs, f, sort_keys=False)
EOF
fi
