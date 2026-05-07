# Bug Research Report: Issue #284

## Description
The `README.md` in `templates/enterprise-gke/` is missing the `## Architecture` header. This is a recurring issue where the file becomes corrupted or wiped entirely.

## Root Cause Analysis
1.  **Linter Conflict**: The `agent-infra/local-lint.sh` script enforces a mandate that the CI marker (`<!-- CI: validation record ... -->`) must be the **absolute last line** of the `README.md` file.
2.  **CI Append Behavior**: The `.github/workflows/ci-post-merge.yml` workflow is designed to **append** a `## Validation Record` table **below** this marker after a successful template validation.
3.  **Resulting Failure**: As soon as CI validates a template and updates its README, the marker is no longer on the last line, causing the linter to fail with `ERROR: Template 'enterprise-gke' README.md CI marker is not on the last line`.
4.  **Agent-Induced Corruption**: Automated agents (specifically `agentdev-agent`) detect these linter failures and attempt to "fix" the README. These agents appear to use a flawed "standardization" process that sometimes overwrites the file with a status report or wipes it to a single newline. This destructive action removes the `## Architecture` header, triggering the specific error reported in Issue #284.

## Evidence
- **Linter Failure on Main**: Running the linter on the current `main` version of `templates/enterprise-gke/README.md` fails due to the marker position, even though the header is present.
- **Wiped File on Branch**: The `fix/issue-284` branch has a 1-byte `README.md` (just a newline) at commit `8e7c7bf`, which was created by `agentdev-agent`.
- **History of Overwrites**: Git logs show multiple commits where `agentdev-agent` replaced the README content with text describing its own actions (e.g., commit `41bc06d` on `main`).

## Proposed Fix Plan
1.  **Relax Linter Constraints**: Modify `agent-infra/local-lint.sh` to remove the requirement that the CI marker be the absolute last line. It only needs to verify the marker exists.
2.  **Restore Enterprise GKE README**: Overwrite the corrupted `templates/enterprise-gke/README.md` with a clean version from a known good state (e.g., from `main` or previous successful commits).
3.  **Standardize and Verify**: Ensure all template READMEs have the marker and header, and verify they pass the updated linter.

## Recommended Changes

### File: `agent-infra/local-lint.sh`
Remove or comment out the strict `tail -n 1` check:
```bash
  # Mandate: CI marker must be the last line of the file (ignoring trailing whitespace)
  # REMOVE THIS CHECK AS IT CONFLICTS WITH ci-post-merge.yml
  # if ! tail -n 1 "${template}/README.md" | grep -q "<!-- CI: validation record"; then
  #   echo "ERROR: Template '${template_name}' README.md CI marker is not on the last line"
  #   exit 1
  # fi
```

### File: `templates/enterprise-gke/README.md`
Restore full content, ensuring it includes:
- `# Enterprise GKE Cluster`
- `## Architecture`
- Deployment paths and verification steps.
- The CI marker `<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->` at the end of the manual content.
