# Bug Research Report: Issue #255

## Title
[CI-BUG] README in templates/enterprise-gke missing CI marker (Validation Record)

## Description
The `README.md` in `templates/enterprise-gke/` is missing the mandatory CI validation record marker. Furthermore, the entire file has been corrupted and replaced with a status report from a previous automated agent. Additionally, the repository's local linter (`agent-infra/local-lint.sh`) is currently broken because it references an undefined variable `MARKER_LINE`.

## Root Cause Analysis

1.  **File Corruption in `enterprise-gke`**: 
    In commit `6c1bc95d617a97ab4ea371b58cf1be4f9f296072`, an automated agent accidentally replaced the entire content of `templates/enterprise-gke/README.md` with its own "resolved" message. This removed the `## Architecture` header, the CI marker, and all other mandatory sections.
    
2.  **Broken Linter Logic**:
    The script `agent-infra/local-lint.sh` contains the following check:
    ```bash
    # Mandate: Validation Record header must follow the marker
    if ! tail -n +$MARKER_LINE "${template}/README.md" | grep -q "^## Validation Record"; then
      echo "ERROR: Template '${template_name}' README.md is missing '## Validation Record' header after the CI marker"
      exit 1
    fi
    ```
    However, `MARKER_LINE` is never defined or initialized in the script. This causes `tail` to fail with an error (`tail: invalid number of lines: ‘+’`), and the linter subsequently reports a failure for every template.

3.  **Destructive Truncation and Workflow Race Conditions**:
    Previous iterations of CI workflows (`sandbox-validation-tf.yml` and `sandbox-validation-kcc.yml`) used destructive `sed` commands to truncate README files at the CI marker. When multiple workflows run concurrently (e.g., TF and KCC validation for the same push), they can race to update the same file, leading to lost updates or corrupted files.

## Similar Errors Identified
- Systemic linter failure affecting all templates due to the `MARKER_LINE` bug.
- Historically, `templates/basic-gke-hello-world/README.md` and others have suffered from table loss, although they appear correct in the current branch state (except for the linter failure).

## Proposed Plan of Action (for Fixer Agent)

### 1. Fix the Local Linter
Modify `agent-infra/local-lint.sh` to correctly define `MARKER_LINE` before using it.
```bash
  # Calculate marker line for header check
  MARKER_LINE=$(grep -n "<!-- CI: validation record" "${template}/README.md" | cut -d: -f1)
  
  # Mandate: Validation Record header must follow the marker
  if ! tail -n +$MARKER_LINE "${template}/README.md" | grep -q "^## Validation Record"; then
    echo "ERROR: Template '${template_name}' README.md is missing '## Validation Record' header after the CI marker"
    exit 1
  fi
```

### 2. Restore `templates/enterprise-gke/README.md`
Reconstruct the `README.md` for `enterprise-gke` using its original content (available in git history) or the `agent-infra/scaffolds/README.template.md`. Ensure it includes:
- `## Architecture` header.
- The standard deployment and verification sections.
- The `<!-- CI: validation record ... -->` marker at the end.
- A `## Validation Record` header following the marker.

### 3. Consolidate CI Update Logic
Ensure that only `ci-post-merge.yml` (and the corresponding step in `sandbox-validation-*.yml` if absolutely necessary) is responsible for updating the README. The Python-based update logic currently present in the workflows is a good step towards robustness, but redundant destructive `sed` calls in shell steps must be removed.

### 4. Verification
Run `./agent-infra/local-lint.sh .` and ensure it passes for all templates.
