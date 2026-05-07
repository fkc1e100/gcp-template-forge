# Bug Research Report: Issue #255

## Title
[CI-BUG] README in templates/enterprise-gke missing CI marker (Validation Record)

## Description
The `README.md` in `templates/enterprise-gke/` was reported as missing the mandatory CI validation record marker. Investigation confirms that while the HTML comment marker `<!-- CI: validation record ... -->` is often present, the actual **Validation Record table** and its corresponding `## Validation Record` header are missing in several templates on the `main` branch. This is a systemic issue caused by conflicting CI workflows and destructive truncation logic.

## Root Cause Analysis

1.  **Destructive Truncation Logic**: Multiple CI workflows (`sandbox-validation-tf.yml` and `sandbox-validation-kcc.yml`) previously used `sed -i '/<!-- CI: validation record/q' "$README"` to truncate the README file at the marker line. If the subsequent update step failed or was skipped (e.g., during documentation-only updates), the README was left in a truncated state with no results table.
2.  **Workflow Race Conditions**: Three separate workflows (`ci-post-merge.yml`, `sandbox-validation-tf.yml`, and `sandbox-validation-kcc.yml`) all attempt to update the same `README.md` and `.validated` files upon a push to the `main` branch. Concurrent runs led to race conditions where updates were lost or overwritten.
3.  **Linter-Driven Manual Deletions**: The linter on the `main` branch was perceived to require the marker to be the absolute last line of the file. This prompted some agents to manually strip existing validation tables to restore a "clean state" (e.g., commit `830730c`), assuming CI would replace it. If CI failed to push, the table remained missing.
4.  **Inadequate Linter Enforcement**: The linter on `main` only verified the existence of the comment marker. It did not enforce the presence of the `## Validation Record` header or the table, allowing corrupted READMEs to pass through.
5.  **Incomplete State Preservation**: The `publish-validated` job in `ci-post-merge.yml` on `main` defaults status to "skipped" if CI artifacts are missing. This causes it to overwrite a previously successful validation record with a "skipped" one during unrelated documentation updates.

## Similar Errors Identified
This issue affected almost all templates, including:
- `templates/basic-gke-hello-world/README.md`
- `templates/gke-fqdn-egress-security/README.md`
- `templates/latest-gke-features/README.md`

## Proposed Plan of Action (for Fixer Agent)

A significant portion of this fix has already been implemented in the `fix/issue-255` branch. The following steps ensure a complete resolution:

### 1. Consolidate README Update Logic
- **Canonical Source**: Designate `.github/workflows/ci-post-merge.yml` as the sole authority for updating the `README.md` validation tables.
- **Remove Redundancy**: Remove all `README.md` update steps and destructive `sed` commands from `sandbox-validation-tf.yml` and `sandbox-validation-kcc.yml`.

### 2. Robustify the Update Script
- **State Preservation**: Update the Python script in `ci-post-merge.yml` to read existing status from the `.validated` file if fresh CI artifacts are missing.
- **Robust Truncation**: Use the Python-based truncation logic to ensure the README content is preserved even if the marker is misplaced.

### 3. Strengthen the Linter
- **Header Enforcement**: Update `agent-infra/local-lint.sh` to require that the `## Validation Record` header follows the marker.
- **Position Enforcement**: Enforce that the marker must be within the last 20 lines of the file.

### 4. Restore Missing Tables
- Iterate through all templates and restore the `## Validation Record` table using data from their respective `.validated` files.

## Verified Fix State
In the current `fix/issue-255` branch:
- The linter has been updated to enforce the `## Validation Record` header.
- `ci-post-merge.yml` uses robust Python logic and preserves state.
- Redundant update logic has been removed from other workflows.
- All template READMEs have had their validation tables restored.
