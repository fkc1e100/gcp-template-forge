# Bug Research Report: Issue #238

## Issue Overview
**Title:** [CI-BUG] basic-gke-hello-world README does not follow standard template
**Description:** The `README.md` in `templates/basic-gke-hello-world/` is inconsistent with the standard defined in `agent-infra/scaffolds/README.template.md`.

Specific missing/inconsistent items reported:
- `<!-- CI: validation record ... -->` comment.
- Inconsistent headers or ordering.

## Root Cause Analysis
The `templates/basic-gke-hello-world/README.md` diverged from the `agent-infra/scaffolds/README.template.md` because it was likely one of the first templates created, possibly before the scaffold was finalized.

While the current branch (`fix/issue-238`) has already applied some fixes to the README, my research identified deeper structural and logic issues:

### 1. README Divergence
- **Status:** Partially fixed in this branch. The headers now follow the scaffold.
- **Remaining Issue:** The `{{KCC_LIMITATIONS_SECTION}}` placeholder is present as a literal string. Since this template has no known KCC limitations (verified against `agent-infra/kcc-capabilities.yaml`), this section should be cleaned up.

### 2. Naming Inconsistency (Code vs. README)
- **The README claims:** KCC resources are named `gke-basic-<uid>-kcc`.
- **The manifests use:** `gke-basic-vpc` and `gke-basic-subnet` (no `-kcc` suffix).
- **The Problem:** This breaks the promise of "functional parity" in naming between TF and KCC paths.

### 3. CI Workflow Bug (Post-Merge)
- **File:** `.github/workflows/ci-post-merge.yml`
- **Logic:** `BASE_NAME=$(basename "$TEMPLATE")` and `sed -i "s/${BASE_NAME}/${BASE_NAME}-${UID_SUFFIX}/g"`.
- **The Conflict:** For `basic-gke-hello-world`, the `BASE_NAME` is the directory name (21 chars), but the manifests use the `shortName` (`gke-basic`).
- **Result:** The `sed` command fails to find and replace the resource names in `basic-gke-hello-world`. This causes CI to attempt to create resources with static names (`gke-basic-vpc`), leading to collisions and failures if multiple jobs run.

### 4. CI Validation Record Logic
- **File:** `.github/workflows/ci-post-merge.yml`
- **Logic:** `echo "## Validation Record..." >> "$README"`.
- **The Conflict:** This appends to the end of the file, ignoring the `<!-- CI: validation record ... -->` marker at the top. This makes the "do not edit below this line" warning in the README misleading.

## Proposed Action Plan

### Step 1: Align Naming and Cleanup README
- **Update Manifests:** Modify `templates/basic-gke-hello-world/config-connector/*.yaml` to use the naming pattern `gke-basic-kcc` for the base resource names. This allows CI to append a UID and matches the README's claims.
- **Cleanup README:** Remove the literal `{{KCC_LIMITATIONS_SECTION}}` from `templates/basic-gke-hello-world/README.md` and replace it with a brief statement or a commented-out block as per scaffold instructions.

### Step 2: Fix CI Workflow (Addressing the [CI-BUG] prefix)
- **Update `ci-post-merge.yml`:** Modify the naming replacement logic to use the `shortName` from `template.yaml` instead of the directory name.
- **Update `ci-post-merge.yml`:** (Optional but recommended) Update the README update logic to search for the marker instead of just appending.

## Detailed Changes for `templates/basic-gke-hello-world/`
- **README.md:** 
    - Ensure CI marker is at line 5.
    - Remove `{{KCC_LIMITATIONS_SECTION}}`.
    - Ensure all `---` rules are in the correct place.
- **config-connector/*.yaml:**
    - Rename `gke-basic` -> `gke-basic-kcc`
    - Rename `gke-basic-vpc` -> `gke-basic-kcc-vpc`
    - Rename `gke-basic-subnet` -> `gke-basic-kcc-subnet`
