# Bug Research Report: Issue #255

## Title
[CI-BUG] README in templates/enterprise-gke missing CI marker (Validation Record)

## Description
The `README.md` in `templates/enterprise-gke/` was reported as missing the mandatory CI validation record marker. Research shows that while the comment marker `<!-- CI: validation record ... -->` is present in all templates, the actual **Validation Record table** following it is missing in almost all templates (except `enterprise-gke` which was recently fixed in this branch). 

This is a systemic issue causing widespread failures in `./agent-infra/local-lint.sh`, which enforces that a `## Validation Record` header must follow the CI marker.

## Root Cause Analysis

1.  **Workflow Race Conditions**: Three separate GitHub workflows attempt to update the same `README.md` and `.validated` files on push to `main`:
    - `.github/workflows/ci-post-merge.yml`
    - `.github/workflows/sandbox-validation-tf.yml`
    - `.github/workflows/sandbox-validation-kcc.yml`
    
    When a PR is merged, all three trigger simultaneously. They all use `git reset --hard origin/main` and `git push`, but their logic for preserving state between them is inconsistent, leading to lost updates.

2.  **Destructive Truncation Logic**: Both `sandbox-validation-tf.yml` and `sandbox-validation-kcc.yml` use `sed -i '/<!-- CI: validation record/q' "$README"` to truncate the file at the marker line. If the subsequent Python script fails or if the workflow is interrupted before the table is appended and pushed, the file is left in a truncated state (marker but no table).

3.  **Linter-Driven Deletions**: Previously, `agent-infra/local-lint.sh` required the CI marker to be the absolute last line of the file. To satisfy this linter, agents (and potentially automated cleanup scripts) manually removed the validation tables, assuming CI would replace them. However, if CI didn't run or failed, the tables remained missing.

4.  **Incomplete State Preservation**: `sandbox-validation-tf.yml` does not preserve the previous "success" status from `.validated` if the current run skips validation (e.g., if only docs changed). It defaults to "skipped", which can overwrite a valid "success" record.

## Current State of Templates

| Template | Marker Present | Table Present | Linter Status |
|---|---|---|---|
| `enterprise-gke` | Yes | Yes | **PASS** |
| `basic-gke-hello-world` | Yes | No | **FAIL** |
| `gke-fqdn-egress-security` | Yes | No | **FAIL** |
| `gke-inference-fuse-cache` | Yes | No | **FAIL** |
| `gke-topo-routing` | Yes | No | **FAIL** |
| `kuberay-kueue` | Yes | No | **FAIL** |
| `latest-gke-features` | Yes | No | **FAIL** |
| `test-kcc-skip` | Yes | No | **FAIL** |

## Proposed Plan of Action (for Fixer Agent)

### 1. Restore Missing Tables
Restore the `## Validation Record` section to all affected templates. The data can be reconstructed from the existing `${TEMPLATE}/.validated` files.

### 2. Consolidate README Update Logic
- Modify `.github/workflows/ci-post-merge.yml` to be the **canonical** source for README updates.
- Remove the redundant (and destructive) `sed -i` and Python-based README updates from `sandbox-validation-tf.yml` and `sandbox-validation-kcc.yml`. These workflows should focus on updating the `.validated` file and let `ci-post-merge.yml` handle the README presentation.
- Ensure `ci-post-merge.yml` properly reads the existing state from `.validated` to avoid overwriting "success" with "skipped".

### 3. Robustify `publish-validated` in `ci-post-merge.yml`
Update the Python script in `ci-post-merge.yml` to:
- Handle potential missing artifacts gracefully.
- Ensure it always appends a valid table if the marker is found.
- (Optional) Add a check to ensure the marker is indeed near the end of the file before truncating.

### 4. Update Linter to be Informative
Ensure `agent-infra/local-lint.sh` provides clear instructions on how to restore a missing table (e.g., "Run CI or manually restore from .validated").

## Specific Steps for Fixer
1.  **For each template** (except `enterprise-gke`):
    - Read `.validated` to get `validated_at`, `commit`, `tf_helm`, and `kcc`.
    - Append the `## Validation Record` header and the table to `README.md` following the marker.
2.  **Edit `.github/workflows/ci-post-merge.yml`**:
    - Ensure it uses the logic to preserve `TF_STATUS` and `KCC_STATUS` from `.validated` if artifacts are missing.
3.  **Edit `.github/workflows/sandbox-validation-tf.yml` and `kcc.yml`**:
    - Remove the `Update README and mark validated` steps, or simplify them to only update the `.validated` file and avoid touching the `README.md`.
4.  **Run `./agent-infra/local-lint.sh`** to verify all templates now pass.
