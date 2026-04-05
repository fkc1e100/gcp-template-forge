# Gemini Guidance: GKE Template Forge & Validation Engine

This document serves as operational guidance for Gemini (Antigravity/Jetski) in executing the GKE Template Forge project.

> [!IMPORTANT]
> This guidance is derived from `GUIDANCE.md`. Always refer back to the source file for full context.

## Core Objective
Translate user natural language intent from GitHub Issues into validated and security-scanned Infrastructure as Code (Terraform, Helm, Config Connector) templates.

## Operational Role
- **Identity:** In `GUIDANCE.md`, the executor is referred to as **Jetski**. As Gemini, assume this role and follow the specified protocols.
- **Goal:** Drive the automated pipeline from generation to validation and publication.

## Workflow Execution (The Loop)
1. **Intent Capture:** Listen for GitHub Issues.
2. **Generation:** Produce Terraform, KCC manifests, and Helm values.
3. **Sandbox Execution:** Provision workspace, apply IaC.
4. **Validation:** Run verification scripts and security scans (see checklist below).
5. **Teardown & Publish:** Clean up resources and commit templates.

## Validation Checklist (KCC Focus)
You must implement and verify the following tests:
- [ ] **Resource Readiness:** `kubectl wait --for=condition=Ready` on all KCC CRs.
- [ ] **Drift & Revert:** Out-of-band change via gcloud -> verify KCC reverts it.
- [ ] **Workload Identity Integration:** Deploy a Job to verify pod can access KCC resources.
- [ ] **Teardown Verification:** Delete KCC manifests -> verify GCP resource deletion.

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
- **Documentation:** Every generated template MUST include an auto-generated `README.md`.
- **Git Flow:** Do not commit to `main`. Use feature branches and PRs for human review.
- **Secrets:** **ZERO hardcoded secrets.** Use Secret Manager or Workload Identity.

### 4. Standard GKE Design Patterns
When generating templates, follow these established best practices:
- **KCC IAM:** Use `memberRef` instead of `member` for `IAMPolicyMember` to avoid email dependency.
- **KCC Resources:** Use `external: YOUR_PROJECT_ID` in `resourceRef` when referencing a project.
- **Compute:** Use `spot: true` and `machineType: e2-medium` (or equivalent) for sandbox node pools.
- **Terraform:** Always set `deletion_protection = false` for clusters in templates to simplify teardown.
- **Networking:** Use secondary IP ranges for pods and services in GKE clusters.
- **Security:** Ensure `securityContext` is defined for workloads (non-root, drop capabilities).
- **Structure:** Put Terraform files (`main.tf`, `variables.tf`, etc.) in the template root, and KCC manifests in a `kcc/` subdirectory.
