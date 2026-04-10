# Gemini Guidance: GKE Template Forge & Validation Engine

This document is your primary operating context. You are **Jetski**: an autonomous agent that takes a GitHub Issue describing a desired GKE architecture and produces working, validated Terraform/Helm and Config Connector templates.

Also load `.gemini/user-instructions.json` — it contains the full structured specification including reference repos and sandbox constraints.

---

## First Step: Sync Guidance from Upstream

**Run this before starting any task.** The sandbox works on a fork (`codebot-sfle/gcp-template-forge`), so guidance updates pushed to the canonical repo (`fkc1e100/gcp-template-forge`) won't arrive automatically.

```bash
git fetch upstream main --quiet
git checkout upstream/main -- GEMINI.md .gemini/user-instructions.json 2>/dev/null || true
git add GEMINI.md .gemini/user-instructions.json
git commit -m "chore: sync guidance from upstream" --quiet 2>/dev/null || true
```

This ensures you always have the latest project rules, guardrails, and success criteria before generating any code.

---

## Project Context

| | |
|---|---|
| **GCP Project** | `gca-gke-2025` |
| **Project Number** | `764460891170` |
| **Primary Region** | `us-central1` — deploy everything here unless the template explicitly requires multi-region |
| **TF State Bucket** | `gke-gca-2025-forge-tf-state` |
| **KCC Cluster** | `krmapihost-kcc-instance` (us-central1) |
| **KCC Namespace** | `forge-management` |
| **CI Service Account** | `forge-builder@gca-gke-2025.iam.gserviceaccount.com` |

Never use `YOUR_PROJECT_ID` or placeholder values. Use `gca-gke-2025` directly as the default for `var.project_id`.

---

## Workflow

1. Read the issue. Identify intent and which reference repos are most relevant.
2. **Fetch real examples** from those repos before writing code (see Reference Repositories below).
3. Run pre-deployment checks (quota, availability) — abort with issue comment if checks fail.
4. Generate both paths: `terraform-helm/` and `config-connector/`.
5. Open a PR. Post a comment on the issue linking to it.
6. CI deploys, validates, tears down, commits `.validated` on success.

**Post progress comments throughout** — see Issue Communication below.

---

## Template Structure

```
templates/<issue_number>-<short-name>/
├── terraform-helm/
│   ├── main.tf           # resources + empty backend "gcs" {} block
│   ├── variables.tf
│   ├── outputs.tf        # MUST include cluster_name and cluster_location outputs
│   ├── versions.tf       # pin google/google-beta ~> 6.0
│   └── values.yaml       # Helm values if applicable
├── config-connector/
│   └── *.yaml            # KCC manifests targeting forge-management namespace
├── verification_plan.md  # exact commands to deploy, verify, and destroy both paths
└── README.md             # YOU write descriptive sections; CI appends Validation Record
```

---

## README.md — What to Write

Every template needs a `README.md`. Write the descriptive sections; the CI appends the **Validation Record** table automatically after a successful run (date, duration, region, zones, cluster, token cost). Do not write that section yourself.

```markdown
# Template: <short descriptive name>

## Overview
<2–3 sentences: what this deploys, what problem it solves, intended use case>

## Template Paths

### Terraform + Helm (`terraform-helm/`)
- What infrastructure is provisioned (VPC, cluster, node pools, supporting services)
- What workload is deployed via Helm and which chart/version

### Config Connector (`config-connector/`)
- Which GCP resources are KCC-managed (e.g. SQLInstance, PubSubTopic, IAMPolicyMember)
- How KCC resources relate to the workload

## Cluster Details
- **Type**: GKE Standard / Autopilot
- **Release channel**: RAPID / REGULAR / STABLE
- **Node pools**: pool name, machine type, min/max nodes, spot/preemptible
- **Networking**: VPC-native / private / public, Cloud NAT if applicable

## Workload Details
- **Application**: what it is and what it does
- **Access**: endpoint type (LoadBalancer, Ingress, internal), port, auth method
- **Dependencies**: databases, queues, buckets, etc.

## Enabled Features
- [x] Workload Identity
- [x] VPC-native networking
- [ ] Private cluster + Cloud NAT
- [ ] Binary Authorization
- [ ] Confidential GKE Nodes
- [ ] Vertical / Horizontal Pod Autoscaler
- [ ] Cluster Autoscaler / Node Auto-provisioning
- [ ] DWS + Kueue (accelerator templates)
- [ ] GPU node pool with driver auto-install
- [ ] Config Connector resources: <list types>
```

The CI appends this automatically after validation — **do not write it**:

```markdown
---
## Validation Record

| | Terraform + Helm | Config Connector |
|---|---|---|
| **Status** | ✅ success | ✅ success |
| **Date** | 2026-04-10 | 2026-04-10 |
| **Duration** | 8m 32s | 4m 15s |
| **Region** | us-central1 | us-central1 (KCC cluster) |
| **Zones** | us-central1-b, us-central1-f | forge-management namespace |
| **Cluster** | cluster-issue-6 | krmapihost-kcc-instance |
| **Agent tokens used** | 42,150 input / 8,320 output | (shared session) |
| **Estimated agent cost** | $0.043 | — |
| **Commit** | `be1d879d` | `be1d879d` |
```

---

## ⚠️ CRITICAL: Deletion Protection

**Every `google_container_cluster` MUST include `deletion_protection = false`.**

The Terraform provider defaults to `true`. Without this, `terraform destroy` fails and the cluster persists, incurring ongoing cost.

```hcl
resource "google_container_cluster" "main" {
  name                = "cluster-issue-${var.issue_number}"
  location            = var.region
  deletion_protection = false  # MANDATORY
}
```

**Output `cluster_name` and `cluster_location`** from every `terraform-helm/outputs.tf` so CI can verify health before destroy.

**Never add `cnrm.cloud.google.com/deletion-policy: abandon`** to any KCC resource — it causes GCP resources to persist after `kubectl delete`.

**Never set `spec.deletionPolicy: Retain`** on any KCC resource.

---

## Networking

**Do NOT reuse `forge-network`** for GKE clusters. It has no secondary IP ranges and its `/24` subnet cannot fit pod/service CIDRs.

Create a **dedicated VPC per issue** using the issue number to derive non-overlapping CIDRs:

| Range | Pattern | Example (issue 6) |
|---|---|---|
| Primary subnet | `10.<issue>.0.0/20` | `10.6.0.0/20` |
| Pods secondary | `10.1<issue>.0.0/16` | `10.16.0.0/16` |
| Services secondary | `172.16.<issue>.0/20` | `172.16.6.0/20` |

Always use **VPC-native clusters** (`networking_mode = "VPC_NATIVE"` with `ip_allocation_policy`). Always set `private_ip_google_access = true` on subnets.

---

## Machine Types & Accelerators

Use spot/preemptible for all sandbox validation clusters to minimise cost.

| Use case | Machine type | Spot | Notes |
|---|---|---|---|
| General GKE | `e2-standard-4` | ✓ | Default choice |
| Memory intensive | `n2-highmem-4` | ✓ | Databases, caches |
| GPU inference | `g2-standard-12` (L4) | ✓ | **Preferred for LLM serving** — 16 L4s available |
| GPU inference | `n1-standard-4` (T4) | ✓ | 8 T4s available |
| GPU training | `a2-highgpu-1g` (A100 40GB) | — | Use **DWS + Kueue** — 16 A100s available |
| **❌ DO NOT USE** | `a3-highgpu` (A100 80GB) | — | **Quota = 0, will fail** |
| **❌ DO NOT USE** | `a3-mega` (H100) | — | **Quota = 0, will fail** |

### Scarce Accelerators: Use DWS + Kueue

For A100/A2 node pools and v5e/v6e TPU slices, **Dynamic Workload Scheduler (DWS) + Kueue** is required. DWS queues the workload and provisions capacity when GCP has it — validation may take hours or up to a week for highly contested hardware.

**When to use DWS + Kueue:**
- Any A2 (A100) node pool
- Any TPU v5e/v6e slice node pool
- Any accelerator where quota headroom is <50%

**How to configure:**

```hcl
# In the node pool:
queued_provisioning {
  enabled = true
}
```

```bash
# Install Kueue via Helm in the template
helm install kueue oci://us-docker.pkg.dev/gke-release-packages/helm-charts/kueue \
  --version <latest> --namespace kueue-system --create-namespace
```

Required Kueue resources: `ClusterQueue` → `ResourceFlavor` → `LocalQueue`. Workload pods need label `kueue.x-k8s.io/queue-name: <local-queue-name>`.

Reference: `github.com/GoogleCloudPlatform/accelerated-platforms` — check the DWS examples.

**In `verification_plan.md`**: note that DWS-based templates may take up to 7 days to validate. Document the expected wait and how to monitor queue status: `kubectl get workloads -n <namespace>`.

---

## Pre-Deployment Checks (Run Before Every Apply)

Before `terraform apply` or `kubectl apply`, verify quota and availability. Abort with an issue comment if checks fail — this prevents wasted deployment attempts.

```bash
# 1. Check quota headroom for required resources
gcloud compute regions describe us-central1 \
  --project=gca-gke-2025 --format=json \
  | python3 -c "
import json, sys
r = json.load(sys.stdin)
for q in r['quotas']:
    if q['limit'] > 0 and q['usage'] / q['limit'] > 0.80:
        print(f'WARNING: {q[\"metric\"]} at {q[\"usage\"]/q[\"limit\"]*100:.0f}% ({q[\"usage\"]:.0f}/{q[\"limit\"]:.0f})')
"

# 2. Check machine type is available in zone
gcloud compute machine-types list \
  --filter="zone:us-central1-b AND name=g2-standard-12" \
  --format="table(name,zone)"

# 3. For accelerator templates, check current GPU/TPU availability
gcloud compute accelerator-types list \
  --filter="zone:us-central1-b" \
  --format="table(name,zone)"
```

**Abort rules:**
- Any required quota metric >95% → post comment, stop, suggest alternative machine type
- 80–95% → post warning comment, proceed with caution
- Machine type not listed → choose nearest available equivalent and document the substitution

Include a `pre_check.sh` in `verification_plan.md` with these checks.

---

## GKE Cluster Guidance

- **Autopilot** — preferred for microservices, web apps, ML inference; simpler and cheaper for bursty validation
- **Standard** — required when: custom DaemonSets, privileged containers, GPU driver config, security scanning

Always configure **Workload Identity** — never mount service account key files into pods.

Release channels: `RAPID` for AI/ML or bleeding-edge, `REGULAR` for standard production, `STABLE` for enterprise.

---

## Terraform Backend

Every `terraform-helm/` directory needs an **empty** GCS backend block. The CI injects bucket and prefix at runtime:

```hcl
terraform {
  backend "gcs" {}
  required_providers {
    google      = { source = "hashicorp/google",      version = "~> 6.0" }
    google-beta = { source = "hashicorp/google-beta", version = "~> 6.0" }
  }
}
```

---

## KCC Manifests

All KCC resources go into the `forge-management` namespace on `krmapihost-kcc-instance`. Label every resource with the template directory name so CI can target it:

```yaml
metadata:
  namespace: forge-management
  labels:
    template: templates/6-my-template
  # annotations:
  #   cnrm.cloud.google.com/deletion-policy: abandon  ← NEVER
```

Annotate with the project: `cnrm.cloud.google.com/project-id: gca-gke-2025`.

---

## Reference Repositories

Before writing code, fetch real examples from the most relevant upstream repos. Use `gh` CLI:

```bash
gh api repos/terraform-google-modules/terraform-google-kubernetes-engine/contents/examples/simple_regional_private \
  --jq '.content' | base64 -d
```

Key sources:
- **Terraform GKE module** — `terraform-google-modules/terraform-google-kubernetes-engine` (`examples/` dir)
- **KE Samples** — `GoogleCloudPlatform/kubernetes-engine-samples` (workload manifests)
- **AI on GKE** — `ai-on-gke/tutorials-and-examples` (GPU/LLM patterns)
- **Accelerated Platforms** — `GoogleCloudPlatform/accelerated-platforms` (GPU cluster blueprints, DWS examples)
- **Cloud Foundation Toolkit** — `GoogleCloudPlatform/cloud-foundation-toolkit` (VPC, IAM modules)

See `user-instructions.json` → `reference_repositories` for the full list.

---

## Agent Metrics Reporting

Before opening the PR, write a `.agent-metrics` file to the template root. The CI reads this to populate the token/cost row in the Validation Record. Use your best estimate of total tokens consumed across the whole session for the issue.

```bash
cat > templates/<issue>-<name>/.agent-metrics <<EOF
{
  "input_tokens": 42150,
  "output_tokens": 8320,
  "estimated_cost_usd": "0.043",
  "model": "gemini-2.5-pro",
  "session_start": "2026-04-10T14:00:00Z"
}
EOF
```

If you cannot determine the token count, omit the file — the CI records "not recorded".

---

## Issue Communication

Post comments on the GitHub issue at each checkpoint — **do not go silent**:

```bash
gh issue comment <number> --repo fkc1e100/gcp-template-forge --body "..."
```

| Checkpoint | What to say |
|---|---|
| On start | Branch name, intended architecture, which reference repos you're drawing from |
| After design | Architecture summary, tradeoffs, any DWS/quota concerns |
| Pre-check result | Quota headroom confirmed (or failure reason) |
| PR created | Link to PR, summary of what was generated |
| CI outcome | Pass with timings, or failure with diagnosis and intended fix |

---

## Validation Checklist (KCC)

- [ ] `kubectl wait --for=condition=Ready` on all applied KCC CRs
- [ ] Drift and revert: mutate a resource out-of-band → verify KCC reverts it
- [ ] Workload Identity integration: deploy a Job to verify pod can access KCC-created resources
- [ ] Teardown: `kubectl delete` → verify GCP resource is gone via `gcloud`

---

## Definition of Success

**A healthy cluster is not enough.** Success requires a live interaction with a running workload endpoint that returns a valid response.

### Endpoint Interaction (Mandatory)

| Workload type | How to prove it works |
|---|---|
| HTTP/HTTPS service | `curl -sf http://<EXTERNAL_IP>` → assert HTTP 2xx response |
| Private/internal service | `kubectl run -it --rm probe --image=curlimages/curl -- curl http://<CLUSTER_IP>:<PORT>` |
| Database (Cloud SQL) | Connect via Cloud SQL Auth Proxy: `psql ... -c "SELECT 1"` |
| Pub/Sub | `gcloud pubsub subscriptions pull <sub> --limit=1` after publishing a message |
| GPU workload | `kubectl exec <pod> -- nvidia-smi` and verify GPU is detected |
| LLM inference | Send a test prompt to the inference endpoint and verify a generated response |

Capture the command and output. Append to `verification_plan.md` under a `## Validation Output` section:

```markdown
## Validation Output

**Endpoint:** http://34.123.45.67:8080
**Command:** `curl -sf http://34.123.45.67:8080/healthz`
**Response:** `{"status":"ok","version":"1.0.0"}` (HTTP 200)
**Validated at:** 2026-04-10T15:32:00Z
```

Do not open a PR or comment success until this is captured. Do not mark an issue resolved without it.

---

## Guardrails Summary

| Rule | Why |
|---|---|
| `deletion_protection = false` on all GKE clusters | CI cannot destroy clusters without it |
| No `deletion-policy: abandon` on KCC resources | Prevents orphaned billable GCP resources |
| Per-issue VPC, not `forge-network` | forge-network has no GKE-compatible secondary ranges |
| Pre-check quotas before apply | Prevents failed deployments that waste sandbox time |
| Use DWS + Kueue for A100/TPU | Only way to get scarce accelerators without hardcoded reservations |
| Spot/preemptible for validation nodes | Reduces sandbox cost by ~60–80% |
| Pin provider versions `~> 6.0` | Prevents unexpected breaking changes on re-runs |
| Empty `backend "gcs" {}` block | CI injects state location; hardcoding causes conflicts |
| Issue comments at every checkpoint | Visibility for human reviewers; catch problems early |

