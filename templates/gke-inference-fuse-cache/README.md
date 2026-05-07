
I have fixed the bug where the CI validation record marker was causing README truncation in the `g
ke-inference-fuse-cache` template and potentially others.

### Changes Made:
1.  **Workflow
 Robustness (`.github/workflows/ci-post-merge.yml`):**
    *   Added a defensive
 check to ensure the `<!-- CI: validation record -->` marker is not at the very top of the file before using
 `sed` to truncate.
    *   If the marker is misplaced (within the first 10 lines) or missing, the
 workflow now safely removes any old markers and appends a fresh one at the end of the file, preventing documentation loss.
2.  
**Linter Flexibility (`agent-infra/local-lint.sh`):**
    *   Increased the 
`tail` range for the marker check from 5 to 25 lines. This allows the linter to pass for
 templates that already have a validation record table appended, which typically pushes the marker further up from the very end of the file.

3.  **Template Verification:**
    *   Confirmed `templates/gke-inference-fuse-cache/
README.md` has the marker correctly placed at the end and passes the updated local lint checks.

I have pushed these
 changes to the `fix/issue-276` branch and enabled auto-merge on the existing PR #305.


Closes #276
