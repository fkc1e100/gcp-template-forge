# Bug Research Report: Issue #255

## Title
[CI-BUG] README in templates/enterprise-gke missing CI marker (Validation Record)

## Description
The `README.md` in `templates/enterprise-gke/` is missing the mandatory CI validation record table. While the marker comment `<!-- CI: validation record ... -->` is present at the end of the file, the actual results table is missing. This issue appears to affect multiple templates and is caused by conflicting and flawed logic across several CI workflows.

## Root Cause Analysis

1.  **Workflow Contention**: Three separate GitHub workflows attempt to update the same files (`README.md` and `.validated`) on push to `main`:
    - `.github/workflows/ci-post-merge.yml`
    - `.github/workflows/sandbox-validation-tf.yml`
    - `.github/workflows/sandbox-validation-kcc.yml`
    
    This creates race conditions where one workflow's changes may be overwritten or lost during the `git push` retry loops of others.

2.  **Destructive Truncation Logic**: Both `sandbox-validation-tf.yml` and `sandbox-validation-kcc.yml` use `sed -i '/<!-- CI: validation record/q' "$README"` to truncate the file at the marker line before attempting to append the new record. If the subsequent update step fails (e.g., due to a Python script error or artifact absence), the file is left in a truncated state with no record.

3.  **Loss of Validation State in `ci-post-merge.yml`**: The `ci-post-merge.yml` workflow has a flaw where it defaults `TF_STATUS` to "skipped" if the specific template was not validated in the current run (which happens if only documentation or unrelated files changed). It does NOT preserve the previous "success" status from the `.validated` file, leading it to overwrite valid records with "skipped" status or empty tables.

4.  **Manual "Cleanup" Errors**: Recent commits (e.g., `830730c`) shows agents attempting to "restore README to a clean state" by manually removing the validation record, assuming CI will immediately replace it. However, if the template code hasn't changed, the CI workflows might skip the update or fail to find fresh artifacts, leaving the README without a record indefinitely.

5.  **Marker-only Linter**: The `agent-infra/local-lint.sh` only checks for the *existence* of the marker and its proximity to the end of the file. It does not verify that a valid `## Validation Record` table actually follows the marker.

## Similar Errors Identified
This is a systemic issue affecting most templates, including:
- `templates/basic-gke-hello-world/README.md`
- `templates/latest-gke-features/README.md`
- `templates/gke-fqdn-egress-security/README.md`

## Proposed Plan of Action (for Fixer Agent)

### 1. Consolidate and Robustify README Updates
The update logic should be unified into a single script or action that:
- Loads existing status from `.validated` if a new validation was skipped.
- Only truncates and appends if it has a valid record to write.
- Is used consistently across all three workflows.

### 2. Fix `ci-post-merge.yml` Status Handling
Modify the `publish-validated` job in `ci-post-merge.yml` to read the existing status from `${TEMPLATE}/.validated` when a template's artifact is missing, ensuring "success" is preserved.

### 3. Restore `enterprise-gke/README.md`
Manually (or via script) restore the validation record for `enterprise-gke` using the data from its current `.validated` file:
- **Status**: success
- **Date**: 2026-04-11
- **Commit**: 2c375256
- **TF_Helm**: success
- **KCC**: skipped

### 4. Improve Linter
Update `agent-infra/local-lint.sh` to ensure that a `## Validation Record` header exists if the marker is present, or at least warn if it's missing.

## Actionable Steps for Fixer
1.  **Read** `${TEMPLATE}/.validated` to get the last known good status.
2.  **Append** a standardized table to `templates/enterprise-gke/README.md` following the marker.
3.  **Update** `.github/workflows/ci-post-merge.yml` to preserve state:
    ```bash
    # Proposed logic for ci-post-merge.yml
    if [ ! -f "$TF_RES" ]; then
      TF_STATUS=$(grep '^tf_helm:' "${TEMPLATE}/.validated" | awk '{print $2}' || echo "skipped")
    fi
    ```
4.  **Verify** the fix by running `./agent-infra/local-lint.sh`.
