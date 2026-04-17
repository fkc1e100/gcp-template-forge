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

echo "=== Running Local Linting ==="

# 0. Template structure check
echo "Checking template structure..."
for template in templates/*; do
  [ -d "$template" ] || continue
  template_name=$(basename "$template")
  [ "$template_name" == "README.md" ] && continue
  
  echo "--- Checking $template_name ---"
  MISSING=""
  [ ! -d "${template}/terraform-helm" ] && MISSING="${MISSING} terraform-helm/"
  [ ! -d "${template}/config-connector" ] && MISSING="${MISSING} config-connector/"
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
for dir in $(find templates agent-infra -name "*.tf" -exec dirname {} \; | sort -u); do
  echo "--- Linting TF in $dir ---"
  (
    cd "$dir"
    terraform init -backend=false -input=false > /dev/null
    terraform fmt -check
    terraform validate

    # Mandate: deletion_protection = false for GKE clusters
    if grep -r "google_container_cluster" *.tf > /dev/null 2>&1; then
      if ! grep -r "deletion_protection\s*=\s*false" *.tf > /dev/null 2>&1; then
        echo "ERROR: GKE cluster in $dir missing 'deletion_protection = false'"
        exit 1
      fi
      
      # Mandate: 30m timeouts
      if ! grep -r "create\s*=\s*\"30m\"" *.tf > /dev/null 2>&1; then
        echo "ERROR: GKE cluster in $dir missing '30m' create timeout"
        exit 1
      fi
    fi

    # Mandate: No helm provider or local-exec
    if grep -r "provider \"helm\"" *.tf > /dev/null 2>&1; then
      echo "ERROR: Restricted 'helm' provider found in $dir"
      exit 1
    fi
    if grep -r "local-exec" *.tf > /dev/null 2>&1; then
      echo "ERROR: Restricted 'local-exec' provisioner found in $dir"
      exit 1
    fi
  )
done

# 2. Helm lint
echo "Checking Helm..."
for chart in $(find templates -name "Chart.yaml" -exec dirname {} \; | sort -u); do
  echo "--- Linting Helm chart in $chart ---"
  helm lint "$chart"
  helm template release "$chart" > /dev/null
done

# 3. YAML syntax check (KCC and other plain YAML)
echo "Checking YAML syntax (excluding Helm templates)..."
python3 -c "
import yaml, sys, pathlib
errors = []
for p in pathlib.Path('.').rglob('*.yaml'):
    if '.terraform' in str(p): continue
    # Skip Helm templates as they contain Go template directives
    if 'templates/' in str(p) and any(x in str(p) for x in ['terraform-helm', 'workload']): continue
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
if [ -f "./actionlint" ]; then
  echo "Checking GitHub Actions..."
  ./actionlint
fi

echo "=== Local Linting Passed ==="
