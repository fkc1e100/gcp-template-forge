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

# file-kcc-issues.sh — parse kubectl dry-run output and file [NEW FIELD] issues
# on GoogleCloudPlatform/k8s-config-connector for any unknown fields found.
#
# Usage: file-kcc-issues.sh <dry-run-output-file>
# Env:   GH_TOKEN, PR_URL, TEMPLATE (set by GitHub Actions)

set -euo pipefail

DRY_RUN_OUTPUT="${1:-/tmp/kcc-dry-run.txt}"

if [ ! -f "$DRY_RUN_OUTPUT" ]; then
  echo "No dry-run output file found at $DRY_RUN_OUTPUT -- skipping"
  exit 0
fi

# Detect KCC version from installed CRDs
KCC_VER=$(kubectl get crd containerclusters.container.cnrm.cloud.google.com \
  -o jsonpath='{.metadata.annotations.cnrm\.cloud\.google\.com/version}' \
  2>/dev/null || echo "unknown")

# Extract unique unknown fields, e.g.:
#   ContainerCluster in version "v1beta1" ... unknown field "spec.secretManagerConfig"
grep -oP 'unknown field "\K[^"]+(?=")' "$DRY_RUN_OUTPUT" | sort -u | while read -r FIELD; do

  KIND=$(grep -oP '\w+(?= in version "[^"]+" cannot be handled[^"]*unknown field "'"${FIELD//./\\.}"'")' \
    "$DRY_RUN_OUTPUT" | head -1 || echo "KCCResource")

  TITLE="[NEW FIELD] ${KIND}: add ${FIELD} (detected in KCC dry-run)"

  # Skip if an open issue already mentions this field
  EXISTING=$(gh search issues "${FIELD} ${KIND}" \
    --repo GoogleCloudPlatform/k8s-config-connector \
    --state open --json number --jq length 2>/dev/null || echo "0")
  if [ "$EXISTING" -gt "0" ]; then
    echo "Skipping ${FIELD} -- existing open issue found"
    continue
  fi

  # Build the issue body in a temp file to avoid shell quoting complexity
  BODY_FILE=$(mktemp)
  cat > "$BODY_FILE" << BODY_EOF
## Summary

The KCC \`${KIND}\` resource (CRD version \`v1beta1\`) does not recognise the field \`${FIELD}\`, but it is present in the GKE REST API. This was detected automatically by \`kubectl apply --dry-run=server\` during template PR validation in the [gcp-template-forge](https://github.com/fkc1e100/gcp-template-forge) project.

## Error

\`\`\`
strict decoding error: unknown field "${FIELD}"
\`\`\`

## Desired KCC YAML

\`\`\`yaml
apiVersion: container.cnrm.cloud.google.com/v1beta1
kind: ${KIND}
metadata:
  name: example
spec:
  ${FIELD##*.}: ...   # add support for this field
\`\`\`

## Environment

- **KCC version:** ${KCC_VER}
- **Template:** \`${TEMPLATE:-unknown}\`
- **PR:** ${PR_URL:-n/a}

## References

- GKE REST API reference: https://cloud.google.com/kubernetes-engine/docs/reference/rest/v1/projects.locations.clusters
BODY_EOF

  URL=$(gh issue create \
    --repo GoogleCloudPlatform/k8s-config-connector \
    --title "$TITLE" \
    --body-file "$BODY_FILE" 2>&1)
  echo "Filed: $URL"
  rm -f "$BODY_FILE"
done

echo "Unknown field check complete."
