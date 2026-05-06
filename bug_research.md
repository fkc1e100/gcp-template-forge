# Bug Research Report: Issue #239

## Problem Statement
Issue #239 reports that `templates/gke-inference-fuse-cache/README.md` does not follow the project's standard README template (`agent-infra/scaffolds/README.template.md`). Specific issues mentioned:
- Missing `<!-- CI: validation record ... -->` marker comment.
- Inconsistent headers (uses `## Overview` instead of `## Architecture`).

## Root Cause Analysis
The discrepancy originated from the initial creation of several templates (including `gke-inference-fuse-cache`, `kuberay-kueue`, and others) which used a non-standard format. 

Key findings:
1.  **Header Inconsistency**: The `main` branch version of `templates/gke-inference-fuse-cache/README.md` used `## Overview` as the primary section header, whereas the standard scaffold requires `## Architecture`.
2.  **Comment Misplacement/Missing**: In the `main` branch, the `<!-- CI: validation record ... -->` marker was either missing or placed incorrectly (e.g., above the title). 
3.  **License Headers**: Non-standard license headers were present in some READMEs (e.g., `gke-inference-fuse-cache`), which are not part of the standard scaffold.
4.  **Workflow Limitations**: The current `ci-post-merge.yml` workflow (and other CI scripts) simply appends a `## Validation Record` to the end of the file rather than using the `<!-- CI: validation record ... -->` marker, which may have led to confusion about its presence or purpose.
5.  **Mandate Violations**: The `gke-inference-fuse-cache` template currently includes a `zone` variable that defaults to `us-central1-a`, which violates the project mandate against "GPU zone pinning" (as documented in `GEMINI.md`).

## Current State in `fix/issue-239` Branch
The current branch has already seen multiple commits (e.g., `6da63bc`, `e7ff7ee`) that have addressed the primary issues for `gke-inference-fuse-cache/README.md`:
- The header is now `## Architecture`.
- The `<!-- CI: validation record ... -->` comment is present on line 5, following the title and description.
- `## Template Inputs` section has been added.

However, other templates still do not follow the scaffold:
- `templates/basic-gke-hello-world/README.md`: Missing `## Template Inputs`.
- `templates/kuberay-kueue/README.md`: Uses `## Prerequisites` and is missing `## Template Inputs`.
- `templates/test-kcc-skip/README.md`: Minimalist and non-standard.

## Proposed Action Plan
1.  **Finalize `gke-inference-fuse-cache/README.md`**: Ensure it strictly matches the scaffold's header order and formatting.
2.  **Remove Forbidden `zone` Variable**: Update `templates/gke-inference-fuse-cache/` to remove the `zone` variable from `variables.tf`, `main.tf`, and `README.md` to comply with the GPU zone pinning mandate.
3.  **Standardize Other Templates**: Apply similar fixes to `basic-gke-hello-world`, `kuberay-kueue`, and `test-kcc-skip` to ensure project-wide consistency.
4.  **Enhance CI Workflow**: (Long-term) Update `ci-post-merge.yml` to use the marker comment for inserting the validation record instead of appending to the end of the file.

## Specific Changes Needed for `gke-inference-fuse-cache/README.md`
- [x] Change `## Overview` to `## Architecture`. (Already done in current branch)
- [x] Add/Move `<!-- CI: validation record ... -->` comment to line 5. (Already done in current branch)
- [x] Add `## Template Inputs` section. (Already done in current branch)
- [ ] Remove `zone` input from `## Template Inputs` and related sections to comply with GPU mandates.
