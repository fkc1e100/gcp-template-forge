# Project Infrastructure: gca-gke-2025 & Repo-Agent

## Overview
The project infrastructure is hosted on Google Cloud Platform (Project: `gca-gke-2025`) and consists of a management cluster and a workload cluster. The system uses Kubernetes-native patterns to manage both infrastructure (via Config Connector) and automated repository agents (via the Repo-Agent platform).

## Clusters

### 1. Management Cluster (KCC Host)
*   **Context:** `gke_gca-gke-2025_us-central1_krmapihost-kcc-instance`
*   **Role:** Acts as the control plane for Google Cloud resources.
*   **Key Components:**
    *   **Config Connector (KCC):** Installed in `cnrm-system`. It allows managing GCP resources (IAM, Service Accounts, etc.) using Kubernetes manifests.
    *   **Namespace `forge-management`:** Configured with a `ConfigConnectorContext` pointing to the `forge-kcc-admin@gca-gke-2025.iam.gserviceaccount.com` service account to manage project-specific infrastructure.

### 2. Workload Cluster (Repo-Agent Standard)

### Network Access (Gateway)
*   **Gateway IP:** `34.30.138.59` (Gateway resource `repo-agent-gateway` in `repo-agent-system`)
*   **Repo-Agent Dashboard / UI:** Accessible directly via the Gateway IP at `http://34.30.138.59/`
*   **Repo-Agent API / Sandbox:** Accessible via the Gateway IP at `http://34.30.138.59/api` and `http://34.30.138.59/sandbox`

#### Troubleshooting Access Issues
If the dashboard is inaccessible from specific devices or networks:
*   **GCP Firewall Rules:** Access is allowed from `0.0.0.0/0` via rule `k8s-fw-a11aadadca2e941b68de468681bbf467`. However, it targets specific node tags (`gke-repo-agent-standard-0b155b4f-node`). Ensure no local/corporate firewalls block the public IP.
*   **Load Balancer Health Checks:** The L7 Load Balancer uses Google health check ranges (`130.211.0.0/22`, `35.191.0.0/16`). If backends are slow to start, the LB may temporarily drop traffic.
*   **MTU/VPN Mismatches:** If using a VPN, ensure the MTU is compatible with GCP's standard settings to avoid packet fragmentation issues.
*   **Context:** `gke_gca-gke-2025_us-central1_repo-agent-standard`
*   **Role:** Runs the application workloads and the agent platform.
*   **Key Components:**
    *   **Namespace `repo-agent-system`:** Core platform services.
        *   `repowatch-controller`: Monitors repositories for changes, issues, and PRs.
        *   `syncer`: Handles repository synchronization.
        *   `github-mcp-server`: Model Context Protocol server for GitHub integration.
        *   `registry`: Local container registry for agent workloads.
    *   **Namespace `overseer-system`:**
        *   `overseer-controller`: Manages the lifecycle of `Overseer` custom resources.
    *   **Namespace `fkc1e100`:**
        *   Specific sandbox for the `gcp-template-forge` project.
        *   Hosts dynamic PR sandboxes (e.g., `gcp-template-forge-pr-18`).

## Workload Flow
1.  **Overseer CRD:** An `Overseer` resource is created to define a managed repository (e.g., `https://github.com/fkc1e100/gcp-template-forge`).
2.  **RepoWatch:** The `repowatch-controller` detects the resource and begins monitoring the repository for events (PRs, Issues).
3.  **Sandboxing:** For active PRs or tasks, the system spins up dedicated pods/services in the strictly designated project namespace (`fkc1e100`) to perform analysis, reviews, or automated fixes.
4.  **Telemetry:** Cluster health and node status are tracked, with specialized tools (like the Matrix Portal integration) providing readiness checks and display mocks.

## Local Configuration
*   **Binary Tools:** `actionlint` is present in the project root for CI/CD linting tasks.
*   **Editor Settings:** `.claude/settings.local.json` contains local environment configurations.

## MCP Servers
```json
{
  "mcpServers": {
    "gke-mcp": {
      "command": "npx",
      "args": ["-y", "@googlecloud/gke-mcp"]
    }
  }
}
```

## Engineering Mandates
*   **Resource Labeling:** ALL infrastructure resources (GKE clusters, subnets, etc.) created by the agent MUST include the label `project: gcp-template-forge`. This ensures clear ownership and easier cleanup.
*   **Timeouts:** Always use a minimum of 30-minute timeouts when waiting for GKE cluster readiness.
*   **Separation of Concerns (Terraform vs. Helm):** NEVER use `local-exec` provisioners or the Terraform Helm provider to deploy Helm charts or Kubernetes manifests within `main.tf`. Terraform's sole responsibility is infrastructure provisioning. The CI/CD pipeline (`sandbox-validation.yml`) contains a dedicated, authenticated `Helm deploy and verify` step that automatically handles workload deployment. Use `local_file` in Terraform to dynamically generate a `values.yaml` file for the downstream Helm step to consume.

#### `fkcurrie/gcp-template-forge` (dashboard namespace, drives what you see in the UI)
```yaml
spec:
  repoURL: https://github.com/fkc1e100/gcp-template-forge
  pollIntervalSeconds: 300       # 5-minute poll (slower than fkc1e100's 60s)
  githubSecretName: github-pat
  issue:
    assignedToSelf: false        # IMPORTANT: must be false to see all issues
    robotAccount: codebot-sfle
    issues: [15, 16]             # explicit list — only these issue numbers are handled
    maxSandboxes: 6
    maxActiveSandboxes: 6
    handlers:
    - name: fix
      labels: [repo-agent]
      excludeLabels: [hold]
      taskType: fix-issue
      prompt: "Fix this issue"
  review:
    maxSandboxes: 3
    maxActiveSandboxes: 3
    reviewShutdownAfterMinutes: 30
```

**Important fields:**
- `assignedToSelf: true` → only issues assigned to the robot GitHub account are handled. **If no issues appear in the dashboard, check this field first — it was the root cause of the dashboard showing nothing.**
- `issues: []` → watch ALL issues; `issues: [15, 16]` → only those numbers
- `excludeLabels: [hold]` → issues with the `hold` label are skipped even if all other criteria match
- `robotAccount: codebot-sfle` → the GitHub bot that commits/comments; must exist as a Kubernetes secret in `repo-agent-system/codebot-sfle` for the controller to copy it to user namespaces

**Force immediate reconciliation** (without waiting for next poll):
```bash
kubectl annotate repowatch -n fkcurrie gcp-template-forge \
  reconcile-trigger="$(date +%s)" --overwrite
```

---

### Secret Architecture

| Secret Name | Namespace(s) | Contents | Purpose |
|---|---|---|---|
| `codebot-sfle` | `repo-agent-system`, `fkc1e100`, `fkcurrie`, `overseer-gcp-template-forge` | `email`, `name`, `pat`, `userid` | GitHub bot identity and PAT for git operations |
| `github-pat` | `fkc1e100`, `fkcurrie` | GitHub PAT | RepoWatch polls GitHub API with this |
| `gemini-vscode-tokens` | `fkc1e100`, `fkcurrie` | Gemini API keys | LLM calls from sandbox agents |
| `gemini-api-key` | `repo-agent-system` | Gemini API key | System-level LLM key |
| `github-token` | `repo-agent-system` | GitHub token | pr-review-api OAuth |
| `repo-agent-tls` | `repo-agent-system` | TLS cert | Envoy Gateway TLS |
| `huggingface-token` | GCP Secret Manager (`gca-gke-2025`) | HuggingFace token | Model weight access; **never in git** |

**Secret copy mechanism:** `repowatch-controller` reads `{robotAccount}` from `repo-agent-system` as the **source** and copies it into the user namespace (e.g., `fkcurrie/codebot-sfle`). The source secret **must exist in `repo-agent-system`** — if it only exists in `fkc1e100`, the copy will fail with "Failed to find robot secret codebot-sfle in repo-agent-system".

**Race condition pattern:** The controller uses `Create` (not `CreateOrUpdate`) for the copy. If two reconcile goroutines run simultaneously (triggered by rapid annotation updates), the second will fail with "already exists". This is harmless — on the next clean single-goroutine reconciliation, the secret is already there and everything proceeds normally.

---

### Sandbox Lifecycle

When a RepoWatch controller matches a GitHub issue:

1. **Sandbox created** in the user namespace (e.g., `fkcurrie/gcp-template-forge-issue-16`)
   - `spec.podTemplate` describes the pod
   - `initContainers[0]`: `inject-agent` — copies the `repo-sandbox` binary from `ghcr.io/gke-labs/gemini-for-kubernetes-development/repo-sandbox:latest` into the workspace
   - Main container: runs `repo-sandbox dev-daemon` — a gRPC server that listens for task commands
   - Image is built from `agent-infra/sandbox-image/Dockerfile` using `generic-golang` as the base (pre-installs `terraform`, `helm`, `kubectl`, `yq`)

2. **SandboxTask created** (e.g., `fkcurrie/gcp-template-forge-issue-16-fix`)
   - Labels include `review.gemini.google.com/repowatch: gcp-template-forge` — this is what makes `repowatch-controller` process it
   - `spec.type: fix-issue` — tells the controller which task to dispatch
   - `spec.params` includes: `ISSUEID`, `AGENT_PROMPT`, `HANDLER_NAME`, `model`, `AGENT_LLM_PROVIDER`, `AGENT_LLM_API_KEY_SECRET`

3. **Controller dispatches** the task via gRPC to the sandbox's `dev-daemon` server

4. **Agent runs** — `repo-sandbox` executes the Gemini CLI agent with the task parameters; the agent clones the repo, makes changes, commits, and opens a PR

5. **Task completes** — `status.taskState: Completed` is set when the agent finishes

**Iterate tasks** (e.g., `gcp-template-forge-issue-15-1776086878-iterate`): Created when the controller wants the agent to re-examine the issue after CI feedback. These have no `STATE` column in `kubectl get sandboxtask` until the controller dispatches them.

---

### Terraform State Lock Mechanism

CI uses a GCS backend with conditional writes (`If-None-Match: *`) for locking:

- **Lock file path pattern:** `gs://gke-gca-2025-forge-tf-state/templates/<template-name>/terraform-helm/default.tflock`
- **Stale lock symptom:** CI fails with HTTP 412 (Precondition Failed) on "Initialize and Upgrade Terraform" step; logs show `Error acquiring the state lock` with a lock ID
- **How to check:** `gsutil ls gs://gke-gca-2025-forge-tf-state/templates/ 2>/dev/null`
- **How to remove:** `gsutil rm gs://gke-gca-2025-forge-tf-state/templates/<name>/terraform-helm/default.tflock`
- **After removing:** Re-trigger CI by pushing a commit or using `gh run rerun`. Be aware that if two CI jobs run concurrently for the same template path, they will race to acquire the lock and one will fail with 412 — this is normal and the failing run just needs to be retried.

**State bucket:** `gke-gca-2025-forge-tf-state` in project `gca-gke-2025`. The `forge-builder` service account has `storage.objectAdmin` on this bucket.

---

### Kyverno Policies

Three ClusterPolicies are active:

| Policy | Scope | Effect |
|---|---|---|
| `halve-sandbox-resources` | Pods in `fkcurrie` namespace with label `agents.x-k8s.io/sandbox-name-hash` | Forces CPU request/limit to 1000m/2000m and memory request/limit to 1Gi/2Gi — overrides whatever the sandbox spec requests. This halves resource allocation for dashboard sandboxes vs. the fkc1e100 originals. |
| `gfk-gke-compat` | Cluster-wide | GKE compatibility fixes for the operator stack |
| `replace-ko-image-references` | Cluster-wide | Rewrites `ko://` image references to resolved GHCR digests |

**Impact of `halve-sandbox-resources`:** Sandbox pods in `fkcurrie` always run with 1 CPU / 1Gi RAM regardless of what the template requests. This is intentional — the dashboard namespace is a secondary monitoring view, not a high-performance execution namespace. The `fkc1e100` namespace runs sandboxes at full resources.

---

### Dashboard (pr-review-api) Behavior

- **URL:** `https://34.30.138.59/` (Envoy Gateway, not the legacy GCE ingress at `34.117.252.80`)
- **Auth:** GitHub OAuth — browser session required for namespace selection
- **Namespace selection:** Derived from the authenticated user's GitHub login: `f` + last name of the login. For `fkc1e100`, this is `fkcurrie`.
- **Issues tab:** Shows `issueSandboxes` from the RepoWatch in the user's personal namespace (`fkcurrie`)
- **PRs tab:** Shows `reviewSandboxes` from the same RepoWatch
- **If Issues tab is empty:** Check `kubectl get repowatch -n fkcurrie gcp-template-forge -o jsonpath='{.spec.issue.assignedToSelf}'` — if `true`, only issues GitHub-assigned to the robot account will appear. Set to `false` to show all matching issues.
- **Dashboard manages fkcurrie RepoWatch:** If you delete the `fkcurrie/gcp-template-forge` RepoWatch, the dashboard recreates it with its default settings (may reset `assignedToSelf` to `true` and clear your custom config). Prefer patching rather than deleting.

---

### CI/CD Workflow (sandbox-validation.yml)

The CI pipeline (`.github/workflows/sandbox-validation.yml`) runs on every push to any branch and on PRs:

1. **Authenticate** — Workload Identity Federation (WIF) using the CI SA `forge-builder@gca-gke-2025.iam.gserviceaccount.com`. WIF is **blocked for fork PRs** — OIDC tokens are not issued to forked repositories by GitHub's security model.

2. **Terraform lint** — `terraform fmt -check -recursive` and `terraform validate` for every `terraform-helm/` directory in the PR's changed files

3. **Deploy & Test TF+Helm** — `terraform init` (with injected GCS backend), `terraform apply`, workload health check, `terraform destroy`

4. **Deploy & Test KCC** — applies KCC manifests to `forge-management` namespace on `krmapihost-kcc-instance`, validates, deletes

5. **Break stale TF state lock** — a dedicated step that checks for and removes stale `.tflock` files before the Terraform init. If no lock exists, this step succeeds silently.

6. **Commit `.validated` marker** — on success, CI commits a `.validated` file and appends the Validation Record to `README.md`

**WIF Fork Fix:** Push branch to upstream (`fkc1e100/gcp-template-forge`) and open the PR from there:
```bash
git push upstream HEAD
gh pr create --repo fkc1e100/gcp-template-forge \
  --head "$(git rev-parse --abbrev-ref HEAD)" \
  --title "..." --body "Closes #N ..."
```

---

### Robot Account: codebot-sfle

- **GitHub username:** `codebot-sfle`
- **GitHub email:** `codebot-sfle@sfle.ca`
- **GitHub name:** `Codebot SFLE`
- **Fork repo:** `codebot-sfle/gcp-template-forge` (the agent's `origin` remote)
- **Upstream repo:** `fkc1e100/gcp-template-forge` (canonical, where branches must be pushed for WIF)
- **Write access:** `codebot-sfle` has direct push access to `fkc1e100/gcp-template-forge` — **do not push to origin (the fork) if you intend CI to run**
- **Secret key fields:** `pat` (GitHub PAT), `email`, `name`, `userid`

**In the sandbox:** the `GITHUB_BOT_LOGIN` env var is `codebot-sfle`. The `GITHUB_USER_LOGIN` is `fkc1e100` (the repo owner). The `gh` CLI is authenticated as `codebot-sfle` via the mounted `GITHUB_TOKEN`/`MANUAL_PAT` secret.

---

### Sandbox Image (agent-infra/sandbox-image/Dockerfile)

The sandbox image is built from:
```
FROM ghcr.io/gke-labs/gemini-for-kubernetes-development/generic-golang:latest
```

Tools pre-installed at image build time (not at runtime):
- `terraform` — downloaded from HashiCorp releases API (binary, no apt repo)
- `helm` — installed via the official get-helm-3 script
- `kubectl` — installed via `gcloud components install kubectl`
- `yq` — downloaded from mikefarah/yq GitHub releases

**This means you do NOT need to install these tools at sandbox startup** — they are already available. The "Sandbox Environment" section earlier in this document (showing install-if-missing scripts) reflects the older pre-image-update state. With the current image, just call `terraform`, `helm`, `kubectl`, `yq` directly.

---

### Issue & PR Flow Summary

```
GitHub Issue (label: repo-agent, no hold) 
  → repowatch-controller (polling fkc1e100 repo, 60s interval)
    → creates Sandbox in user namespace (fkc1e100 or fkcurrie)
    → creates SandboxTask (type: fix-issue, label: review.gemini.google.com/repowatch)
      → controller dispatches gRPC command to sandbox dev-daemon
        → repo-sandbox runs Gemini CLI agent
          → agent clones repo, makes changes, pushes to upstream, opens PR
            → GitHub Actions: sandbox-validation.yml triggers
              → TF lint → deploy → validate → destroy → commit .validated
                → CI passes: PR can be merged, issue closed

GitHub PR (opened or new commit)
  → repowatch-controller (review handler)
    → creates Sandbox in user namespace (PR review sandbox)
    → sandbox reviews the PR diff, posts a comment with approval/feedback

CI failure on PR
  → Overseer triggered (if issue has "overseer" label)
    → overseer-cli creates Sandbox+SandboxTask in overseer-gcp-template-forge
    → [KNOWN ISSUE] SandboxTask has no repowatch label → never dispatched
    → Overseer logs "infrastructure stall" → human intervention required
    → Manual action: check stale TF lock, fix code, push new commit
```

## KCC Limitations vs Terraform
**NEVER use Terraform attributes in KCC manifests.** Config Connector is usually 6 to 12 months behind Terraform in feature parity. If a feature does not exist in the Config Connector sample repository, assume it is unsupported and use standard configurations. For example, KCC v1beta1 `ContainerNodePool` does NOT support `queuedProvisioning` — if asked to use DWS flex-start, you must fall back to standard `spot = false` and `machineType` for KCC, while using `queued_provisioning` in the Terraform path.

## AI Model Staging Pattern
**Do not force Helm to wait for massive model downloads.** For AI workloads (like vLLM) that download 10GB+ weights from Hugging Face into a GCS bucket, the `Deployment` will fail its readiness probe and cause `helm upgrade` to timeout.
*   **The Standard Pattern:** Deploy a Kubernetes `Job` *first* to stage the model weights to the bucket. The actual `Deployment` (e.g., vLLM) must use an init-container that simply waits for the `Job` to complete before starting the vLLM server. This decouples the slow download from the workload's readiness probe, preventing Helm from timing out.
*   **Progress Deadline:** By default, Kubernetes marks a `Deployment` as failed if it does not progress within 600 seconds (10 minutes). If your model download takes longer, Helm will fail with "Progress deadline exceeded". You MUST explicitly set `progressDeadlineSeconds: 3600` on any AI model serving `Deployment` spec to allow sufficient time for the init-container to complete.

## Handling GCP Quota Errors (NETWORKS, CPUs, etc.)
If your CI run fails with a quota limit error (e.g., `Quota 'NETWORKS' exceeded. Limit: 30.0 globally` or similar stockout/limit messages), it means previous CI runs have left orphaned resources clogging up the project. You must not attempt to modify your template code if the only failure is a quota limit. 

Instead, execute the following command in your terminal to manually trigger the garbage collector workflow:
```bash
gh workflow run cleanup-orphans.yml --repo fkc1e100/gcp-template-forge
```
After running this command, wait 2 to 3 minutes for the backend infrastructure to be deleted, then push an empty commit to your branch to re-trigger your CI pipeline:
```bash
git commit --allow-empty -m "ci: retry after quota cleanup"
git push origin HEAD
```

---

