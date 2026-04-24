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

echo "Suffixing manifests for $FULL_NAME with $UID_SUFFIX"

# 1. Suffix based on full template name (Standard)
find "${TEMPLATE_PATH}/config-connector"* -type f -name "*.yaml" -exec sed -i "s/${FULL_NAME}/${FULL_NAME}-${UID_SUFFIX}/g" {} +

# 2. Special cases for shortened resource names to avoid GCP limits (30 chars for GSAs)
# We use specific prefixes to ensure all resources are uniquely named in shared environments.
if [[ "$FULL_NAME" == "gke-inference-fuse-cache" ]]; then
  echo "Applying special suffixing for gke-inference-fuse-cache"
  # Suffix node service account
  find "${TEMPLATE_PATH}/config-connector"* -type f -name "*.yaml" -exec sed -i "s/gke-inf-fuse-node/gke-inf-fuse-node-${UID_SUFFIX}/g" {} +
  # Suffix other resources using the shortened prefix
  find "${TEMPLATE_PATH}/config-connector"* -type f -name "*.yaml" -exec sed -i "s/gke-inf-fuse-cache/gke-inf-fuse-cache-${UID_SUFFIX}/g" {} +
  # Suffix any remaining workload specific resources
  find "${TEMPLATE_PATH}/config-connector"* -type f -name "*.yaml" -exec sed -i "s/gke-inf-fuse-workload/gke-inf-fuse-workload-${UID_SUFFIX}/g" {} +
fi

if [[ "$FULL_NAME" == "gke-kuberay-kueue-multitenant" ]]; then
  echo "Applying special suffixing for gke-kuberay-kueue-multitenant"
  # Suffix node service account
  find "${TEMPLATE_PATH}/config-connector"* -type f -name "*.yaml" -exec sed -i "s/gke-ray-mt-node/gke-ray-mt-node-${UID_SUFFIX}/g" {} +
fi
