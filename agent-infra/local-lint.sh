#!/bin/bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

TARGET_DIR=${1:-"."}

echo "=== Running Local Linting on ${TARGET_DIR} ==="

# 0. Template structure check
if [ "$TARGET_DIR" == "." ]; then
  echo "Checking all template structures..."
  TEMPLATES=$(find templates -maxdepth 1 -mindepth 1 -type d | sort)
else
  if [[ "$TARGET_DIR" == templates/* ]]; then
    TEMPLATES="$TARGET_DIR"
  else
    TEMPLATES=""
  fi
fi

for template in $TEMPLATES; do
  template_name=$(basename "$template")
  [ "$template_name" == "README.md" ] && continue
  
  echo "--- Checking structure of $template_name ---"
  MISSING=""
  [ ! -d "${template}/terraform-helm" ] && MISSING="${MISSING} terraform-helm/"
  if [ ! -f "${template}/.kcc-unsupported" ]; then
    [ ! -d "${template}/config-connector" ] && MISSING="${MISSING} config-connector/"
  fi
  if [ -n "$MISSING" ]; then
    echo "ERROR: Template '${template_name}' is missing required directories:${MISSING}"
    exit 1
  fi

  # Check for non-standard directories
  for bad in Terraform_HELM terraform_helm terraform-HELM helm Helm terraform manifests; do
    if [ -d "${template}/${bad}" ]; then
      echo "ERROR: Found non-standard directory '${template_name}/${bad}/' -- use 'terraform-helm/' and 'config-connector/'"
      exit 1
    fi
  done
done

# 1. Terraform fmt and validate + Mandates
echo "Checking Terraform and Mandates..."
find "$TARGET_DIR" -name "*.tf" -not -path "*/.*" -exec dirname {} \; | sort -u | while read -r dir; do
  echo "--- Linting TF in $dir ---"
  (
    cd "$dir"
    terraform init -backend=false -input=false > /dev/null
    terraform fmt -check
    terraform validate

    # Mandate checks (only for templates, agent-infra has some exceptions but we'll try to follow)
    # Mandate: deletion_protection = false for GKE clusters
    if grep -q "google_container_cluster" *.tf; then
      if ! grep -q "deletion_protection\s*=\s*false" *.tf; then
        echo "ERROR: GKE cluster in $dir missing 'deletion_protection = false'"
        exit 1
      fi
      
      # Mandate: 30m timeouts
      if ! grep -q "create\s*=\s*\"30m\"" *.tf; then
        echo "ERROR: GKE cluster in $dir missing '30m' create timeout"
        exit 1
      fi
    fi

    # Mandate: No helm provider or local-exec (except in local-lint.sh itself which we are not linting as TF)
    if grep -q "provider \"helm\"" *.tf; then
      echo "ERROR: Restricted 'helm' provider found in $dir"
      exit 1
    fi
    if grep -q "local-exec" *.tf; then
      echo "ERROR: Restricted 'local-exec' provisioner found in $dir"
      exit 1
    fi
  )
done

# 2. Helm lint
echo "Checking Helm..."
find "$TARGET_DIR" -name "Chart.yaml" -not -path "*/.*" -exec dirname {} \; | sort -u | while read -r chart; do
  echo "--- Linting Helm chart in $chart ---"
  helm lint "$chart"
  helm template release "$chart" > /dev/null
done

# 3. YAML syntax check (KCC and other plain YAML)
echo "Checking YAML syntax (excluding Helm templates)..."
python3 -c "
import yaml, sys, pathlib
errors = []
target = '$TARGET_DIR'
for p in pathlib.Path(target).rglob('*.yaml'):
    if '.terraform' in str(p): continue
    # Skip Helm templates as they contain Go template directives
    path_str = str(p)
    if 'templates' in path_str and 'workload' in path_str and 'templates' in path_str: continue
    try:
        with open(p, 'r') as f:
            list(yaml.safe_load_all(f))
    except Exception as e:
        errors.append(f'{p}: {e}')
if errors:
    for e in errors: print(e)
    sys.exit(1)
"

# 4. Actionlint for workflows
if [ "$TARGET_DIR" == "." ] && [ -f "./actionlint" ]; then
  echo "Checking GitHub Actions..."
  ./actionlint
fi

echo "=== Local Linting Passed ==="
