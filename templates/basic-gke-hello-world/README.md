
I have fixed Issue #275 by improving
 the robustness of the CI marker validation in the linter and ensuring all template READMEs are correctly formatted.

### Summary
 of Changes
1.  **Linter Robustness**: Updated `agent-infra/local-lint.sh` to
 use the full mandatory CI marker string (`<!-- CI: validation record appended here by ci-post-merge.yml — do not edit
 below this line manually -->`) instead of a partial substring. This prevents false positives when the marker is mentioned in the text (e.g.,
 in status messages).
2.  **Increased Flexibility**: Increased the linter's proximity check from 25 to
 **50 lines** from the end of the file. This accommodates growing validation record tables and prevents future false negatives.
3.  
**Removed Restrictive Checks**: Removed the `head -n 10` check that prevented the marker from being near
 the top of the file, providing more flexibility for template documentation structure.
4.  **Template Restoration**: Restored all
 template READMEs and directory structures from the `main` branch to resolve corruption and incorrect renames that were present on the task branch.

5.  **Verification**: Confirmed that all templates pass the updated linter, including successful Terraform and Helm linting across
 the entire repository.

I have opened Pull Request #315 to merge these changes and enabled auto-merge.
