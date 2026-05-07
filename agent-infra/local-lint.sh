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

HAS_YAML=$(python3 -c "import yaml; print('true')" 2>/dev/null || echo "false")
if [ "$HAS_YAML" == "false" ]; then
  echo "WARNING: Python 'yaml' module not found. Some deep linting checks (KCC capabilities, YAML syntax) will be skipped."
  echo "Install it with: pip install PyYAML"
fi

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
  if [ "$LINT_MODE" == "TF" ] || [ -z "$LINT_MODE" ]; then
    [ ! -d "${template}/terraform-helm" ] && MISSING="${MISSING} terraform-helm/"
  fi
  if [ "$LINT_MODE" == "KCC" ] || [ -z "$LINT_MODE" ]; then
    if [ ! -f "${template}/.kcc-unsupported" ]; then
      [ ! -d "${template}/config-connector" ] && MISSING="${MISSING} config-connector/"
    fi
  fi
  if [ -n "$MISSING" ]; then
    echo "ERROR: Template '${template_name}' is missing required directories:${MISSING}"
    exit 1
  fi

  # Mandate: template.yaml must exist with a valid shortName
  if [ ! -f "${template}/template.yaml" ]; then
    echo "ERROR: Template '${template_name}' is missing template.yaml (required for resource naming and index)"
    exit 1
  fi
  
  # Use grep/sed to extract shortName to avoid dependency on PyYAML
  SHORT_NAME=$(grep "^shortName:" "${template}/template.yaml" | sed -E 's/^shortName:[[:space:]]*//' | sed -E 's/^["'\'']//;s/["'\'']$//')
  
  if [ -z "$SHORT_NAME" ]; then
    echo "ERROR: ${template}/template.yaml is missing or has empty 'shortName' field"
    exit 1
  fi
  if [ ${#SHORT_NAME} -gt 20 ]; then
    echo "ERROR: ${template}/template.yaml shortName '${SHORT_NAME}' exceeds 20 characters (${#SHORT_NAME} chars)"
    exit 1
  fi

  # KCC capability check: warn if KCC manifests use known-unsupported fields without .kcc-unsupported
  if [ -d "${template}/config-connector" ] && [ ! -f "${template}/.kcc-unsupported" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    KCC_CAP="${SCRIPT_DIR}/kcc-capabilities.yaml"
    if [ -f "$KCC_CAP" ]; then
      if [ "$HAS_YAML" == "true" ]; then
        python3 - "${template}/config-connector" "$KCC_CAP" "${template}" << 'KCCPY'
import yaml, sys, pathlib
cc_dir, cap_file, template_dir = sys.argv[1], sys.argv[2], sys.argv[3]
caps = yaml.safe_load(open(cap_file))
# Build search entries: use kcc_search_key when present (explicit), else feature name.
# Never use the last segment of tf_field — it's often too generic (e.g. 'enabled').
unsupported = []
for u in caps.get('unsupported', []):
    if u.get('action') != 'kcc-unsupported-marker':
        continue
    search_key = u.get('kcc_search_key') or u.get('feature', '')
    if search_key:
        unsupported.append((search_key, u))
errors = []
for p in pathlib.Path(cc_dir).rglob('*.yaml'):
    try:
        content = p.read_text()
        for search_key, info in unsupported:
            if search_key in content:
                errors.append(f"  {p}: uses '{search_key}' which maps to unsupported TF field '{info['tf_field']}'")
    except Exception:
        pass
if errors:
    print(f"ERROR: {template_dir}/config-connector/ references known-unsupported KCC fields without a .kcc-unsupported marker:")
    for e in errors: print(e)
    print(f"  Fix: create '{template_dir}/.kcc-unsupported' or remove the unsupported field.")
    sys.exit(1)
KCCPY
      else
        echo "Warning: PyYAML missing, skipping deep KCC capability check for $template_name"
      fi
    fi
  fi

  # Check for non-standard directories
  for bad in Terraform_HELM terraform_helm terraform-HELM helm Helm terraform manifests; do
    if [ -d "${template}/${bad}" ]; then
      echo "ERROR: Found non-standard directory '${template_name}/${bad}/' -- use 'terraform-helm/' and 'config-connector/'"
      exit 1
    fi
  done

  # Mandate: README.md must exist and contain Architecture header and CI marker
  if [ ! -f "${template}/README.md" ]; then
    echo "ERROR: Template '${template_name}' is missing README.md"
    exit 1
  fi
  if ! grep -q "## Architecture" "${template}/README.md"; then
    echo "ERROR: Template '${template_name}' README.md is missing '## Architecture' header"
    exit 1
  fi
  if ! grep -q "<!-- CI: validation record" "${template}/README.md"; then
    echo "ERROR: Template '${template_name}' README.md is missing CI validation record marker"
    exit 1
  fi
  
  # Mandate: CI marker must be the last line of the file (ignoring trailing whitespace)
  if ! tail -n 1 "${template}/README.md" | grep -q "<!-- CI: validation record"; then
    echo "ERROR: Template '${template_name}' README.md CI marker is not on the last line"
    exit 1
  fi
done

# 1. Terraform fmt and validate + Mandates
echo "Checking Terraform and Mandates..."
TF_DIRS=$(find "$TARGET_DIR" -name "*.tf" -not -path "*/.*" -exec dirname {} \; | sort -u)
for dir in $TF_DIRS; do
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
HELM_DIRS=$(find "$TARGET_DIR" -name "Chart.yaml" -not -path "*/.*" -exec dirname {} \; | sort -u)
for chart in $HELM_DIRS; do
  echo "--- Linting Helm chart in $chart ---"
  helm lint "$chart"
  CHART_NAME=$(basename "$chart")
  RELEASE_NAME="$CHART_NAME"
  if [ "$CHART_NAME" == "workload" ]; then RELEASE_NAME="release"; fi
  helm template "$RELEASE_NAME" "$chart" > /dev/null
done

# 3. YAML syntax check (KCC and other plain YAML)
echo "Checking YAML syntax (excluding Helm templates)..."
if [ "$HAS_YAML" == "true" ]; then
  TARGET_DIR="$TARGET_DIR" python3 -c "
import yaml, sys, pathlib, os
errors = []
target = os.environ.get('TARGET_DIR', '.')
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
else
  echo "Warning: PyYAML missing, skipping YAML syntax check"
fi

# 4. Actionlint for workflows
if [ "$TARGET_DIR" == "." ] && [ -f "./actionlint" ]; then
  echo "Checking GitHub Actions..."
  ./actionlint
fi

echo "=== Local Linting Passed ==="
