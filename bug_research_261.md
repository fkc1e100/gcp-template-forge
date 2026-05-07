# Bug Research Report: Issue #261

## Title
[CI-BUG] README in templates/latest-gke-features missing CI marker

## Description
The `README.md` in `templates/latest-gke-features/` was identified as missing or having a misplaced mandatory CI validation record marker. This research confirms that several other templates are also affected, and the issue is exacerbated by conflicting logic in multiple CI workflows.

## Root Cause Analysis
1.  **Missing/Misplaced Marker**: Older templates either lacked the `<!-- CI: validation record ... -->` marker or had it placed at the top of the file.
2.  **Destructive CI Truncation**: `.github/workflows/ci-post-merge.yml` uses `sed -i '/<!-- CI: validation record/q' "$README"` to truncate the file at the marker before appending results. If the marker is at the top (e.g., line 5), the entire content below it is deleted.
3.  **Conflicting Workflow Logic**: 
    - `ci-post-merge.yml` uses the marker for truncation and appends a minimal 4-column table.
    - `sandbox-validation-tf.yml` and `sandbox-validation-kcc.yml` (which also run on push to `main`) **ignore the marker** and simply append a large 9-row table to the end of the file after stripping any existing `## Validation Record` section via regex.
    - This creates redundancy and potentially inconsistent README formats depending on which workflow finishes last.
4.  **Linter False Positives**: `agent-infra/local-lint.sh` relies on `python3 -c "import yaml..."` to validate `template.yaml`. Since `PyYAML` is not part of the Python standard library and is missing in some environments, the linter fails silently (redirecting stderr to `/dev/null`) and reports that `shortName` is missing, even when the YAML is valid.
5.  **Template Corruption**: The `latest-gke-features/README.md` was found to be corrupted with agent logs, likely due to a previous failed automated fix attempt that committed the agent's summary instead of the documentation.

## Similar Errors Identified
- `templates/basic-gke-hello-world/README.md`
- `templates/gke-fqdn-egress-security/README.md`
- `templates/gke-inference-fuse-cache/README.md`
- `templates/gke-topology-aware-routing/README.md`
- `templates/kuberay-kueue/README.md`
- `templates/test-kcc-skip/README.md`

## Proposed Fix
1.  **Standardize Marker Placement**: Ensure the following marker is on the very last line of every template `README.md`:
    ```markdown
    <!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->
    ```
2.  **Restore Documentation**: Revert `templates/latest-gke-features/README.md` to its original architectural documentation.
3.  **Unify Workflow Logic**: (Recommended for Fixer) Update `sandbox-validation-tf/kcc.yml` to also use the `<!-- CI: validation record` marker for truncation to ensure a single, consistent append point.
4.  **Fix Linter Dependencies**: Update `local-lint.sh` to use `yq` (which is present in the sandbox image) instead of `python3 -c "import yaml"` to avoid `ModuleNotFoundError` and false positives.

## Plan of Action
1.  **Restoration**: Restore `templates/latest-gke-features/README.md` content.
2.  **Alignment**: Move the marker to the end of the README in all affected templates.
3.  **Linter Update**: Refactor the `shortName` check in `agent-infra/local-lint.sh` to use `yq` or a simpler grep-based check that doesn't depend on external Python libraries.
4.  **Workflow Synchronization**: Ensure both `ci-post-merge.yml` and the sandbox validation workflows target the same marker for consistency.
5.  **Validation**: Run `./agent-infra/local-lint.sh` and verify all templates pass.

## References
- `.github/workflows/ci-post-merge.yml` (Marker-based truncation)
- `.github/workflows/sandbox-validation-tf.yml` (Append-based logic)
- `agent-infra/local-lint.sh` (Python YAML dependency)
- `agent-infra/scaffolds/README.template.md` (Standard marker format)
