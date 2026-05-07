
I have completed the fix
 for Issue #276.

### Summary of Changes
1.  **Defensive CI Workflow**: Modified `.
github/workflows/ci-post-merge.yml` to check for the existence of the `<!-- CI: validation record ...
 -->` marker before attempting to truncate the README. If the marker is missing, it is now safely appended to the end of the
 file, preventing the previous destructive behavior where `sed` would wipe the file if the marker was misplaced.
2.  
**Stricter Linting**: Updated `agent-infra/local-lint.sh` to enforce that the CI marker must
 be within the **last 5 lines** of the `README.md` (down from 20). This ensures that the truncation
 logic in the CI workflow only targets the validation section and doesn't accidentally cut off documentation.
3.  **Validation
**: Verified that all templates, including `gke-inference-fuse-cache`, pass the new stricter linter rules.


The changes have been pushed to the `fix/issue-276` branch, and a Pull Request has been opened with auto-merge
 enabled.

