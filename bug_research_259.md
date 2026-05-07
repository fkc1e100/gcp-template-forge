# Bug Research Report: Issue #259

## Issue Overview
**Title:** [CI-BUG] README in templates/gke-topology-aware-routing missing CI marker
**Issue Number:** 259
**Status:** Valid / Investigated

The `README.md` in `templates/gke-topology-aware-routing/` is reported to be missing the mandatory CI validation record marker. This marker is required by the CI pipeline (`.github/workflows/ci-post-merge.yml`) to append validation results and is enforced by the local linter (`agent-infra/local-lint.sh`).

## Root Cause Analysis

1. **Missing/Misplaced Marker:** The initial version of the template README either omitted the marker or placed it in a position where the linter/CI script could not properly utilize it.
2. **Failed Automated Fixes:** Investigation of the git history on the `fix/issue-259` branch reveals multiple attempts by an automated agent (`agentdev-agent`) to fix the issue. The most recent commit (`4f29255afeacdcfc26f0b74701544a9e919dbcde`) is destructive, having wiped the entire content of the `README.md` file, leaving it with only a single newline (1 byte).
3. **Naming Inconsistency:** The template's `template.yaml` defines the `shortName` as `gke-topo-routing` (16 chars), but the README and some resource naming still use the longer `gke-topology-aware-routing` (26 chars), which violates the 20-character limit mandate for GKE resources.

## Investigation Details

- **Linter Enforcement:** `agent-infra/local-lint.sh` checks for the existence of `## Architecture` and `<!-- CI: validation record ... -->`. It specifically requires the marker to be within the last 5 lines of the file.
- **Branch Comparison:**
    - `main`: The README exists and contains the marker, but it was moved there recently in a merge from #264. It still contains non-standard long resource names.
    - `fix/issue-259`: The README is empty/corrupted.
- **Git History:** Commit `4f29255afeacdcfc26f0b74701544a9e919dbcde` on `fix/issue-259` shows a diff that deletes 159 lines and adds nothing.

## Proposed Fix Plan

The Fixer Agent should perform the following steps:

1. **Restore README Content:** Recover the full content of `templates/gke-topology-aware-routing/README.md`. It is recommended to use the version from the `main` branch as a base.
2. **Standardize Resource Names:**
    - Replace all occurrences of `gke-topology-aware-routing` with `gke-topo-routing` within the README.
    - This includes the `Architecture` section, `Resource Naming` table, and `Deployment Paths` (e.g., GCS bucket prefixes).
3. **Ensure CI Marker Placement:**
    - Ensure the following marker is the absolute last line of the file, preceded by exactly one empty line:
      ```markdown
      <!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->
      ```
4. **Validation:**
    - Run `./agent-infra/local-lint.sh templates/gke-topology-aware-routing` to ensure all structural mandates are met.
    - Verify that no `{{` placeholders remain in the README.

## Affected Files
- `templates/gke-topology-aware-routing/README.md`
