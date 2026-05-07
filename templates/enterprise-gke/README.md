
I have fixed Issue #255,
 which involved the missing CI validation record marker and table in `templates/enterprise-gke/README.md`. My
 investigation revealed a systemic issue where conflicting CI workflows were destructively truncating README files.

### Summary of Changes

1.  **Strengthen
ed Linter**: Updated `agent-infra/local-lint.sh` to enforce that a `## Validation Record` header MUST
 immediately follow the CI marker comment. It also now ensures the marker is within the last 20 lines of the file to prevent excessive
 truncation.
2.  **Consolidated CI Logic**: Designated `.github/workflows/ci-post-merge.yml
` as the single source of truth for README updates. Removed redundant and destructive `sed` update steps from `sandbox-validation
-tf.yml` and `sandbox-validation-kcc.yml`.
3.  **Robust Update Script**: Replaced fragile
 `sed` commands in `ci-post-merge.yml` with a Python script that safely truncates the file at the marker and
 appends a standardized validation table. This script also preserves the existing status from the `.validated` file if a new validation run
 is skipped.
4.  **Restored README Tables**: Manually verified and restored the `## Validation Record` section
 for all existing templates, ensuring they pass the updated linter.
5.  **Updated Scaffold**: Modified `agent-infra/scaff
olds/README.template.md` to include the mandatory header and table, ensuring all new templates are compliant by default.

### Verification Results


*   **Local Lint**: Successfully ran `./agent-infra/local-lint.sh`, which now passes for all templates.

*   **Workflow Audit**: Confirmed that `ci-post-merge.yml` contains the robust update logic and other
 workflows are simplified to only update the `.validated` state file.
*   **Manual Check**: Verified that `templates/enterprise-g
ke/README.md` and other templates now correctly display their validation results.

The changes have been pushed to the
 `fix/issue-255` branch. I have updated the existing Pull Request (#306) and enabled
 auto-merge.

Closes #255
