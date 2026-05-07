
I have completed the fix for Issue #255.

### Summary of Changes

1.  **Standard
ized Validation Record Logic**: Refactored the `publish-validated` job in `.github/workflows/ci-post-merge.
yml` to use a robust Python-based truncation logic. It now correctly identifies the mandatory CI marker (`<!-- CI: validation record ...
 -->`) and appends a standardized vertical table format.
2.  **Unified Workflow Behavior**: Updated the sandbox validation workflows
 (`.github/workflows/sandbox-validation-tf.yml` and `.github/workflows/sandbox-validation-
kcc.yml`) to use the same robust truncation logic. This prevents the "append-only" bug that was
 causing multiple validation records to accumulate and ensures a consistent format across all CI processes.
3.  **Template Restoration &
 Verification**: Verified that `templates/enterprise-gke/README.md` is fully restored and correctly formatted. I also manually appended the
 validation record to `templates/basic-gke-hello-world/README.md` to ensure its documentation is complete
 and consistent with the new standard.
4.  **Validation**: Ran the project's official linter (`./agent-
infra/local-lint.sh`), confirming that all template READMEs satisfy the structural mandates, including correct placement of the CI marker.


I have pushed these changes to the `fix/issue-255` branch and enabled auto-merge on the existing PR
 (#281).

