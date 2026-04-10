# Gemini Guidance: GKE Template Forge & Validation Engine

This document serves as operational guidance for Gemini (Antigravity/Jetski) in executing the GKE Template Forge project.

> [!IMPORTANT]
> This guidance is derived from `GUIDANCE.md`. Always refer back to the source file for full context.

## Core Objective
Translate user natural language intent from GitHub Issues into validated and security-scanned Infrastructure as Code (Terraform, Helm, Config Connector) templates.

Templates are validated by actually deploying them to GCP, confirming they work, then tearing them down automatically. A `.validated` marker is committed to the template directory on success.

## Operational Role
- **Identity:** In `GUIDANCE.md`, the executor is referred to as **Jetski**. As Gemini, assume this role and follow the specified protocols.
- **Goal:** Drive the automated pipeline from generation to validation and publication.

## Workflow Execution (The Loop)
1. **Intent Capture:** Listen for GitHub Issues.
2. **Generation:** Produce Terraform, KCC manifests, and Helm values.
3. **Sandbox Execution:** Provision workspace, apply IaC.
4. **Validation:** Run verification scripts and security scans (see checklist below).
5. **Teardown & Publish:** Clean up resources and commit templates.

---

## ⚠️ CRITICAL: Sandbox Resource Deletion Rules

All resources created during sandbox validation **must be fully deleteable by automation** without any manual intervention. Failure to follow these rules causes `terraform destroy` or `kubectl delete` to fail, leaving orphaned resources that continue to incur costs.

### Terraform / GKE Clusters

**ALWAYS set `deletion_protection = false` on every `google_container_cluster`.**

The Terraform Google provider defaults `deletion_protection` to `true`. If this is not explicitly overridden, `terraform destroy` will error and the cluster will not be deleted.

```hcl
resource "google_container_cluster" "main" {
  name     = "cluster-issue-${var.issue_number}"
  location = var.region

  # MANDATORY: must be false for automated teardown
  deletion_protection = false

  # ... rest of config
}
```

**ALWAYS output `cluster_name` and `cluster_location`** from `terraform-helm/main.tf` so the CI pipeline can verify cluster health before destroy:

```hcl
output "cluster_name"     { value = google_container_cluster.main.name }
output "cluster_location" { value = google_container_cluster.main.location }
```

**ALWAYS use an empty GCS backend block** — the CI injects bucket and prefix at runtime:

```hcl
terraform {
  backend "gcs" {}
}
```

**RECOMMENDED: Use spot/preemptible nodes** for sandbox validation to minimise cost:

```hcl
node_config {
  spot = true   # or: preemptible = true
}
```

### Config Connector / KCC

**NEVER add `cnrm.cloud.google.com/deletion-policy: abandon`** to any KCC resource. This annotation causes the underlying GCP resource to persist after the KCC manifest is deleted, creating orphaned billable resources.

**NEVER set `spec.deletionPolicy: Retain`** on any KCC resource.

**ALWAYS label KCC resources** with `template: <template-dir-name>` so the CI can target them:

```yaml
metadata:
  name: cluster-issue-6
  namespace: forge-management
  labels:
    template: templates/6-my-template   # matches the templates/ directory name
  # annotations:
  #   cnrm.cloud.google.com/deletion-policy: abandon  ← NEVER DO THIS
```

**ALWAYS use issue-number-scoped resource names** to avoid collisions across parallel runs (e.g., `cluster-issue-6`, `network-issue-6`).

---

## Validation Checklist (KCC Focus)
You must implement and verify the following tests:
- [ ] **Resource Readiness:** `kubectl wait --for=condition=Ready` on all KCC CRs.
- [ ] **Drift & Revert:** Out-of-band change via gcloud → verify KCC reverts it.
- [ ] **Workload Identity Integration:** Deploy a Job to verify pod can access KCC resources.
- [ ] **Teardown Verification:** Delete KCC manifests → verify GCP resource deletion via `gcloud`.

## Development Protocols & Guardrails

### 1. Iterative Development
Do **not** build the whole system at once. Follow these phases:
- **Phase 1:** Scaffolding (Repo, GH Actions).
- **Phase 2:** Agent Infra (Terraform in `agent-infra/`).
  > [!CAUTION]
  > Manual intervention is required for GitHub App secrets and Gemini API Key injection before proceeding past Phase 2.
- **Phase 3:** Webhook Integration.
- **Phase 4:** End-to-End Testing (use GIQ example).

### 2. Blocker Management & Escalations
If stuck, do not retry blindly. Follow these escalation paths:
- **IAM Errors:** Halt apply. Create GitHub issue `[BLOCKED] Missing IAM Role`. Stop work on branch.
- **State Locks:** Do not auto-force-unlock. Check for running workflows. Log warning if >15 mins.
- **Quota Limits:** Fallback to standard node pool if GPU quota exceeded. Note fallback in PR/Issue.
- **KCC Incompatibility:** Attempt *one* syntax correction. If it fails, fallback to native Terraform and log failure.

### 3. Standards & Security
- **Idempotency:** Generated code must yield zero changes on re-run.
- **Documentation:** Every generated template MUST include an auto-generated `README.md` and a `verification_plan.md`.
- **Git Flow:** Do not commit to `main`. Use feature branches and PRs for human review.
- **Secrets:** **ZERO hardcoded secrets.** Use Secret Manager or Workload Identity.
