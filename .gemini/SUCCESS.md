# Definition of Success for gcp-template-forge

This file defines exactly what "done" means for every template implementation task.
An agent completing a sub-issue MUST be able to check every item on this list before
declaring success. Merging a PR that cannot pass this checklist is a failure.

---

## The Success Checklist

A template implementation is **successful** when ALL of the following are true:

### 1. Template Structure is Complete

- [ ] `templates/<shortName>/template.yaml` exists with:
  - `shortName` present, ≤ 20 characters, lowercase, hyphens only (no spaces, no underscores)
  - `displayName`, `description`, `gcpServices`, `issueNumber` all populated
- [ ] `templates/<shortName>/README.md` exists and documents BOTH deployment paths
- [ ] `templates/<shortName>/validate.sh` exists and is executable

### 2. Dual-Path Implementation is Present

**Terraform + Helm path (`terraform-helm/`):**
- [ ] `main.tf` provisions all required GCP infrastructure
- [ ] `variables.tf` exposes `project_id`, `region`, `zone` (and any template-specific vars)
- [ ] `outputs.tf` exports cluster name and relevant endpoints
- [ ] `terraform fmt -check` passes with zero diff
- [ ] `terraform validate` passes (after `terraform init`)
- [ ] No `local-exec`, no `helm` provider, no hardcoded project IDs
- [ ] Every `google_container_cluster` has `deletion_protection = false`
- [ ] Every `google_container_node_pool` has `node_locations` explicitly set

**Config Connector path (`config-connector/`):**
- [ ] KCC manifests exist for all GCP resources — OR —
- [ ] `.kcc-unsupported` file exists explaining which features are missing and why
  (citing specific entries from `agent-infra/kcc-capabilities.yaml`)
- [ ] No raw K8s workload manifests (Deployments, Services, etc.) in `config-connector/`

**Workload manifests (`config-connector-workload/`):**
- [ ] All raw K8s manifests (Deployments, Services, ConfigMaps, etc.) are here
- [ ] Valid YAML: `python3 -c "import yaml; list(yaml.safe_load_all(open('file.yaml')))"` passes

### 3. The Workload Actually Works (Most Important)

This is the difference between "infrastructure provisioned" and "success."

- [ ] **`validate.sh` passes all 5 tests**, including Test 5 (Functional Verification):
  - The workload is **Running** (Deployment Available, pods in Running state)
  - The workload is **serving or processing** — proven by ONE of:
    - `curl http://<endpoint>` returns HTTP 2xx
    - `kubectl exec` into pod + client command succeeds (psql, redis-cli PING, grpcurl, etc.)
    - Custom resource reaches Ready/Active condition AND a test job/request completes
  - **Reference:** `templates/basic-gke-hello-world/validate.sh` is the canonical example —
    it curls the LoadBalancer IP and fails hard if the endpoint does not respond.
    Every template must have an equivalent check for its own workload type.

### 4. CI is Green

- [ ] `TF PR Validation` check passes (lint + `terraform validate`)
- [ ] `Sandbox Validation (TF)` check passes (deploy + validate.sh + destroy)
- [ ] `Sandbox Validation (KCC)` check passes — OR — `.kcc-unsupported` is present
- [ ] No stale TF state lock in `gs://gke-gca-2025-forge-tf-state/templates/<name>/`

### 5. PR is Correct

- [ ] PR title format: `feat: implement <shortName> template (closes #<issueNum>)`
- [ ] PR body contains `Closes #<issueNum>` on its own line (required for circuit-breaker)
- [ ] `gh pr merge --auto --merge <PR_NUM> --repo fkc1e100/gcp-template-forge` was run immediately after PR creation
- [ ] Only files under `templates/<shortName>/` are changed — no workflow files, no other templates

> **Critical:** `--auto` is mandatory. It means the PR (and therefore the linked issue) will NOT
> close until every CI check passes — including sandbox deploy, `validate.sh`, and teardown.
> Never use `gh pr merge` without `--auto`. Never manually merge a PR before CI is green.
> The issue staying open is correct and expected while CI runs.

### 6. Published

- [ ] PR is merged to `main` (auto-merge triggered and all checks passed)
- [ ] `.validated` file committed by CI with `tf_helm: success` (and `kcc: success` or `kcc: skipped`)
- [ ] Root `README.md` Published Templates table updated by `ci-post-merge.yml`

### 7. Epic Closure (final step, after BOTH TF + KCC sub-issues succeed)

- [ ] Both `[TF]` and `[KCC]` sub-issues are closed (or one is closed with `.kcc-unsupported`)
- [ ] Parent EPIC issue is closed with a comment linking the merged PRs
- [ ] `status:ai-agent-active` label removed from the EPIC

---

## What is NOT Success

The following do NOT count as success even if CI appears green:

- A `validate.sh` that only runs `kubectl wait --for=condition=available` without any
  functional verification (Test 5 not implemented)
- A PR where `terraform validate` was never run locally
- A KCC path with broken manifests hidden behind `|| true`
- A template that hardcodes `project_id = "gca-gke-2025"` instead of using `var.project_id`
- A PR opened against a fork instead of `fkc1e100/gcp-template-forge` (WIF auth will fail)
- Auto-merge NOT triggered (the PR will sit idle and never merge)

---

## Self-Assessment

Before declaring your sub-issue complete, run this self-check:

```bash
# From the template directory:
cd templates/<shortName>

# 1. TF syntax
terraform -chdir=terraform-helm fmt -check && echo "TF fmt: PASS"

# 2. YAML validity
for f in config-connector/*.yaml config-connector-workload/*.yaml; do
  [ -f "$f" ] && python3 -c "import yaml; list(yaml.safe_load_all(open('$f')))" && echo "$f: PASS"
done

# 3. shortName length
python3 -c "import yaml; d=yaml.safe_load(open('template.yaml')); n=d.get('shortName',''); assert len(n)<=20 and n==n.replace(' ','').replace('_',''), f'shortName FAIL: {n!r}'; print('shortName:', n, 'PASS')"

# 4. validate.sh has Test 5 implemented (not the placeholder exit 1)
grep -q "exit 1" validate.sh && echo "WARNING: validate.sh may still have placeholder exit 1" || echo "validate.sh Test 5: looks implemented"

# 5. PR exists with auto-merge
gh pr list --repo fkc1e100/gcp-template-forge --head "feature/issue-<NUM>" --json number,autoMergeRequest
```
