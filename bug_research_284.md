# Bug Research Report: Issue #284 - Missing Architecture header in templates/enterprise-gke/README.md

## 1. Description
The `README.md` file in `templates/enterprise-gke/` was reported as missing its `## Architecture` header. This was caused by the file being wiped or corrupted during an automated "standardization" process triggered by a linter failure.

## 2. Root Cause Analysis

### A. Linter-CI Conflict
The `agent-infra/local-lint.sh` script previously enforced a strict mandate that the CI validation marker (`<!-- CI: validation record ... -->`) must be the **absolute last line** of the `README.md` file.

However, the `.github/workflows/ci-post-merge.yml` workflow is designed to **append** a `## Validation Record` table **below** this marker after a successful template validation. This creates a state where the README is technically "invalid" according to the linter as soon as it has been validated once.

### B. Automated Corruption
When the linter failed in CI/CD, an automated agent (`agentdev-agent`) attempted to "fix" the template by running a standardization routine. This routine appears to have a bug where, upon failing to find or correctly position the required headers/markers, it overwrites the file with a single newline (or a very short status report), effectively wiping the original content.

This destructive action removed the `## Architecture` header, leading to the error reported in Issue #284.

## 3. Evidence
- **Linter Logic (Pre-fix)**: In commit `8e7c7bf`, `agent-infra/local-lint.sh` contained:
  ```bash
  if ! tail -n 1 "${template}/README.md" | grep -q "<!-- CI: validation record"; then
    echo "ERROR: Template '${template_name}' README.md CI marker is not on the last line"
    exit 1
  fi
  ```
- **Corrupted README**: In commit `8e7c7bf`, the file `templates/enterprise-gke/README.md` was reduced to a single newline character.
- **Header Check Failure**: The linter subsequently failed with `ERROR: Template 'enterprise-gke' README.md is missing '## Architecture' header` because the file was empty.

## 4. Similar Errors
Similar patterns of README corruption have been observed in other templates when linter rules are too rigid or conflict with automated append operations. Issue #241 and #259 also touched upon README standardization issues.

## 5. Plan of Action (Fixed)
The fix has already been implemented in the latest commit (`74e9e06`) of the `fix/issue-284` branch:

1.  **Relax Linter Constraints**: Modified `agent-infra/local-lint.sh` to remove the `tail -n 1` check. The script now only verifies that the marker exists anywhere in the file.
2.  **Restore Content**: Restored the full, correct content of `templates/enterprise-gke/README.md` from a known good state.
3.  **Validation**: Verified that the restored README now passes the updated linter even with a validation record appended at the end.

## 6. Recommended Changes (for record)

### File: `agent-infra/local-lint.sh`
```bash
<<<<
  # Mandate: CI marker must be the last line of the file (ignoring trailing whitespace)
  if ! tail -n 1 "${template}/README.md" | grep -q "<!-- CI: validation record"; then
    echo "ERROR: Template '${template_name}' README.md CI marker is not on the last line"
    exit 1
  fi
====
  # Note: We no longer enforce the marker being on the last line because ci-post-merge.yml
  # appends a validation table below it, which would cause immediate linter failures.
>>>>
```

### File: `templates/enterprise-gke/README.md`
Restore full content including:
- `# Enterprise GKE Cluster`
- `## Architecture`
- `## Deployment Paths`
- `<!-- CI: validation record ... -->` marker.
