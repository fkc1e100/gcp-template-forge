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
find "${TEMPLATE_PATH}/config-connector" -type f -name "*.yaml" -exec sed -i "s/${FULL_NAME}/${FULL_NAME}-${UID_SUFFIX}/g" {} +

# 2. Special cases for shortened resource names to avoid GCP limits (30 chars for GSAs)
if [[ "$FULL_NAME" == "gke-inference-fuse-cache" ]]; then
  echo "Applying special suffixing for gke-inference-fuse-cache"
  find "${TEMPLATE_PATH}/config-connector" -type f -name "*.yaml" -exec sed -i "s/gke-inf-fuse-node/gke-inf-fuse-node-${UID_SUFFIX}/g" {} +
  find "${TEMPLATE_PATH}/config-connector" -type f -name "*.yaml" -exec sed -i "s/gke-inf-fuse-cache/gke-inf-fuse-cache-${UID_SUFFIX}/g" {} +
  find "${TEMPLATE_PATH}/config-connector" -type f -name "*.yaml" -exec sed -i "s/gke-inf-fuse-workload/gke-inf-fuse-workload-${UID_SUFFIX}/g" {} +
fi

if [[ "$FULL_NAME" == "gke-kuberay-kueue-multitenant" ]]; then
  echo "Applying special suffixing for gke-kuberay-kueue-multitenant"
  find "${TEMPLATE_PATH}/config-connector" -type f -name "*.yaml" -exec sed -i "s/gke-ray-mt-node/gke-ray-mt-node-${UID_SUFFIX}/g" {} +
fi

# 3. CI-specific Patching for projects with restricted IAM permissions
if [[ "$PROJECT_ID" == "gca-gke-2025" ]]; then
  echo "Detected CI environment, applying IAM workarounds..."
  
  # Use Python for robust YAML patching
  python3 - <<EOF
import yaml
import sys
import pathlib

shared_sa = "${SHARED_SA}"
project_id = "${PROJECT_ID}"

def patch_doc(doc):
    if not isinstance(doc, dict):
        return doc
    
    # 1. Remove IAMServiceAccount
    if doc.get("kind") == "IAMServiceAccount":
        return None
        
    # 2. Replace serviceAccountRef
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
    
    # 3. Replace member emails in IAMPolicyMember
    if doc.get("kind") == "IAMPolicyMember":
        spec = doc.get("spec", {})
        member = spec.get("member", "")
        if member.startswith("serviceAccount:") and project_id in member:
            spec["member"] = f"serviceAccount:{shared_sa}"
            
    return doc

for p in pathlib.Path("${TEMPLATE_PATH}/config-connector").rglob("*.yaml"):
    with open(p, "r") as f:
        try:
            docs = list(yaml.safe_load_all(f))
        except yaml.YAMLError:
            continue
    
    new_docs = [patch_doc(d) for d in docs]
    new_docs = [d for d in new_docs if d is not None]
    
    if len(new_docs) != len(docs) or any(True for d in new_docs if d != None): # Always dump to be safe
        print(f"Patching {p} for CI workarounds")
        with open(p, "w") as f:
            yaml.safe_dump_all(new_docs, f, sort_keys=False)
EOF
fi
