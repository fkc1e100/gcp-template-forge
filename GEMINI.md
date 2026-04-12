# Gemini Guidance: GKE Template Forge & Validation Engine

## Guardrails

- **Template scope**: Only modify files within `templates/<your-template-directory>/`. Never touch other template directories or files that don't belong to your task.
- **Resource naming**: All GCP resource names must be derived from the template directory name. Use a **`-tf` suffix** for Terraform-managed GCP resources and a **`-kcc` suffix** for Config Connector-managed GCP resources so both validation paths can run in parallel without name collisions. Examples: `enterprise-gke-tf` (TF cluster), `enterprise-gke-tf-vpc`, `enterprise-gke-kcc` (KCC cluster), `enterprise-gke-kcc-vpc`. Do NOT use issue numbers (no `issue-6`, `workload-6`, etc.).
- **No merging other PRs**: Never merge changes from other open PRs or branches into your working branch.
- **No new workflow files**: Never create `.github/workflows/` files. `sandbox-validation.yml` is the only CI workflow and must not be modified except via explicit instruction.

This document is your primary operating context. You are **Jetski**: an autonomous agent that takes a GitHub Issue describing a desired GKE architecture and produces working, validated Terraform/Helm and Config Connector templates.

Also load `.gemini/user-instructions.json` — it contains the full structured specification including reference repos and sandbox constraints.

---

## First Step: Sync Guidance and Resolve Divergence

**Run this before starting any task.** The sandbox works on a fork (`codebot-sfle/gcp-template-forge`), so guidance updates pushed to the canonical repo (`fkc1e100/gcp-template-forge`) won't arrive automatically. Also, CI workflow fixes and merge commits pushed to the PR branch from outside the sandbox can cause the local branch to diverge — always reconcile first.

```bash
# 1. Ensure rebase-on-pull is set (prevents fast-forward failures)
git config --global pull.rebase true
git config --global rebase.autoStash true

# 2. Fetch all remotes
git fetch --all --quiet

# 3. If local branch has diverged from upstream (fkc1e100), reset to upstream
# NOTE: origin = codebot-sfle fork, upstream = fkc1e100/gcp-template-forge (canonical)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if git ls-remote --exit-code upstream "refs/heads/${BRANCH}" >/dev/null 2>&1; then
  git fetch upstream "${BRANCH}" --quiet
  git checkout -B "${BRANCH}" "upstream/${BRANCH}"
fi

# 4. Sync guidance files from upstream main (always pull latest, even mid-branch)
git fetch upstream main --quiet
git checkout upstream/main -- GEMINI.md .gemini/user-instructions.json 2>/dev/null || true
git add GEMINI.md .gemini/user-instructions.json 2>/dev/null || true
git commit -m "chore: sync guidance from upstream main" --quiet 2>/dev/null || true
```

This ensures you always have the latest project rules and a clean working tree before generating any code.

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

**Do not hardcode `gca-gke-2025` or any project-specific value as a `default` in `variables.tf`.** Leave `project_id` and `service_account` with no default (required variables) — CI injects them via `TF_VAR_project_id` and `TF_VAR_service_account` environment variables set in the workflow. Templates are published for external use; a hardcoded sandbox default leaks into every downstream deployment.

---

## Workflow

1. Read the issue and classify the template type (see Mandatory Design Research below).
2. **Fetch reference files** using the commands for your template type — do this before writing a single line of code.
3. Post an issue comment listing which files you fetched and your intended architecture.
4. Run pre-deployment checks (quota, availability) — abort with issue comment if checks fail.
5. Generate both paths: `terraform-helm/` and `config-connector/`, using fetched examples as the baseline.
6. Open a PR — **push to `upstream` (fkc1e100), not `origin` (the fork)**. CI uses Workload Identity Federation (WIF) which requires the PR branch to live in the upstream repo. A PR from a fork will always fail with OIDC token / 403 errors regardless of code correctness.

```bash
# Push branch to upstream (codebot-sfle has write access to fkc1e100/gcp-template-forge)
git push upstream HEAD

# Open PR from the upstream branch — NOT from origin/fork
gh pr create \
  --repo fkc1e100/gcp-template-forge \
  --head "$(git rev-parse --abbrev-ref HEAD)" \
  --title "<title>" \
  --body "Closes #<issue-number> ..."
```

7. CI deploys, validates, tears down, commits `.validated` on success.

**If you close a PR and open a replacement** (e.g., a major redesign): close the old PR with a comment "Superseded by #<new-PR>" before opening the new one. This keeps the issue's Development panel accurate — one open linked PR at a time.

**Post progress comments throughout** — see Issue Communication below.

---

## Sandbox Environment

The following tools are **pre-installed** in the sandbox:

| Tool | Path | Notes |
|---|---|---|
| `gcloud` | `/usr/bin/gcloud` | Authenticated via Workload Identity; includes `gke-gcloud-auth-plugin` |
| `gh` | `/usr/local/bin/gh` | Authenticated via mounted secret |
| `git` | `/usr/bin/git` | |
| `curl` | `/usr/bin/curl` | |
| `jq` | `/usr/bin/jq` | |

The following tools are **not pre-installed** — install them before first use:

```bash
# Install terraform (run once per sandbox session — binary download, no apt/lsb_release needed)
if ! which terraform &>/dev/null; then
  TF_VER=$(curl -fsSL https://api.releases.hashicorp.com/v1/releases/terraform/latest \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['version'])")
  curl -fsSL "https://releases.hashicorp.com/terraform/${TF_VER}/terraform_${TF_VER}_linux_amd64.zip" \
    -o /tmp/terraform.zip
  cd /tmp && unzip -q terraform.zip && mv terraform /usr/local/bin/ && rm terraform.zip
  terraform version
fi

# Install helm (run once per sandbox session)
if ! which helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    | HELM_INSTALL_DIR=/usr/local/bin bash
fi

# Install kubectl (run once per sandbox session)
if ! which kubectl &>/dev/null; then
  gcloud components install kubectl --quiet
fi
```

Run these installs **at the start of your first task** so all subsequent steps have the full toolchain available.

The GitHub MCP server also provides structured read access to GitHub repos.

---

## Mandatory Design Research

**Do not write any Terraform, Helm, or KCC YAML from memory.** Fetch proven, working examples from the reference repositories first and use them as the baseline. This prevents the entire class of errors that come from LLM-hallucinated configs (wrong API fields, incorrect resource relationships, outdated patterns).

`gh` CLI and `curl` are available in the sandbox. The GitHub MCP server also provides structured read access to GitHub repos.

### Step 1 — Classify the template

| If the issue mentions… | Template type | Fetch set |
|---|---|---|
| GPU, L4, A100, vLLM, LLM, inference, model serving | **GPU / LLM inference** | Set A below |
| GKE + database, GKE + Pub/Sub, GKE + Cloud SQL | **GKE + managed service** | Set B below |
| private cluster, VPC, networking, security hardening | **Standard / enterprise GKE** | Set B below |
| Config Connector, KCC | **KCC path** | Always fetch Set C in addition |

### Step 2 — Fetch for your type (copy-paste these commands)

#### Set A — GPU / LLM inference

```bash
mkdir -p /tmp/refs && cd /tmp/refs

# 1. L4 GPU node pool Terraform (proven config with correct taints/labels)
gh api repos/GoogleCloudPlatform/accelerated-platforms/contents/platforms/gke/base/core/container_node_pool/gpu/region/us-central1/container_node_pool_gpu_l4_rtx.tf \
  --jq '.content' | base64 -d > gpu_node_pool.tf

# 2. vLLM Deployment manifest for Gemma on L4 (resource requests, GPU limits, tolerations)
gh api repos/GoogleCloudPlatform/kubernetes-engine-samples/contents/ai-ml/llm-serving-gemma/vllm/vllm-2b-it.yaml \
  --jq '.content' | base64 -d > vllm_deployment.yaml

# 3. DWS flex-start TorchJob example (shows queued_provisioning pattern in use)
gh api repos/ai-on-gke/tutorials-and-examples/contents/dws-flex-training-pytorch/training/templates/torch_job.yaml \
  --jq '.content' | base64 -d > dws_torch_job.yaml

# 4. Browse the vLLM inference reference arch directory for additional context
gh api repos/GoogleCloudPlatform/accelerated-platforms/contents/platforms/gke/base/use-cases/inference-ref-arch/kubernetes-manifests/online-inference-gpu/vllm \
  --jq '.[].name'
```

#### Set B — Standard / enterprise GKE

```bash
mkdir -p /tmp/refs && cd /tmp/refs

# 1. VPC-native cluster Terraform (VPC + subnet + GKE using official modules)
gh api repos/terraform-google-modules/terraform-google-kubernetes-engine/contents/examples/simple_regional_with_networking/main.tf \
  --jq '.content' | base64 -d > gke_cluster.tf

# 2. Simple HTTP workload Deployment
gh api repos/GoogleCloudPlatform/kubernetes-engine-samples/contents/quickstarts/hello-app/manifests/helloweb-deployment.yaml \
  --jq '.content' | base64 -d > workload_deployment.yaml

# 3. LoadBalancer Service
gh api repos/GoogleCloudPlatform/kubernetes-engine-samples/contents/quickstarts/hello-app/manifests/helloweb-service-load-balancer.yaml \
  --jq '.content' | base64 -d > workload_service.yaml
```

#### Set C — Config Connector (KCC) path — always fetch alongside Set A or B

```bash
mkdir -p /tmp/refs/kcc && cd /tmp/refs/kcc

# 1. KCC ContainerCluster (VPC-native, with node pool)
gh api repos/GoogleCloudPlatform/k8s-config-connector/contents/config/samples/resources/containercluster/vpc-native-container-cluster/container_v1beta1_containercluster.yaml \
  --jq '.content' | base64 -d > containercluster.yaml

# 2. KCC ComputeNetwork
gh api repos/GoogleCloudPlatform/k8s-config-connector/contents/config/samples/resources/containercluster/vpc-native-container-cluster/compute_v1beta1_computenetwork.yaml \
  --jq '.content' | base64 -d > computenetwork.yaml

# 3. KCC ComputeSubnetwork (with secondary IP ranges for pods/services)
gh api repos/GoogleCloudPlatform/k8s-config-connector/contents/config/samples/resources/containercluster/vpc-native-container-cluster/compute_v1beta1_computesubnetwork.yaml \
  --jq '.content' | base64 -d > computesubnetwork.yaml
```

### Step 3 — Read what you fetched, then adapt

Read each fetched file fully before writing your template. Adapt (don't copy verbatim) to match:
- Template naming conventions (`<name>-tf`, `<name>-kcc`)
- CIDR slot assigned to this template (see Networking section)
- Required fields from GEMINI.md (deletion_protection, backend "gcs", outputs)
- Any issue-specific requirements

### Step 4 — Post a design comment before writing code

```bash
gh issue comment <number> --repo fkc1e100/gcp-template-forge --body "$(cat <<'EOF'
**Design checkpoint — reference files fetched:**
- \`gpu_node_pool.tf\` from GoogleCloudPlatform/accelerated-platforms (L4 node pool config)
- \`vllm_deployment.yaml\` from kubernetes-engine-samples (vLLM resource requests)
- KCC ContainerCluster + Network + Subnetwork from k8s-config-connector samples

**Intended architecture:** <2-3 sentence summary>
**CIDR slot:** <N> (primary <x.x.x.x/20>)
**Key decisions:** <any tradeoffs>
EOF
)"
```

This comment is a checkpoint — it proves you fetched before you wrote, and gives the human reviewer a chance to redirect before you spend time generating the wrong thing.

---

## Issue Gating: the `hold` Label

File an issue before the required GCP resources (quota, reservations, service accounts, APIs) are confirmed as available. Use the `hold` label to freeze it in place until you're ready.

### How the two-component gate works

| Component | Trigger | Blocked by |
|---|---|---|
| **Overseer** | `overseer` label on issue | Not adding `overseer` label |
| **PR Review / RepoWatch** | RepoWatch controller in `fkc1e100` namespace | `excludeLabels: ["hold"]` — any issue with `hold` label is skipped |

Both components independently check for `hold`. You must clear **both** gates to start agent work.

### Issue lifecycle

```
1. File issue with labels: ["hold"]        ← system ignores it entirely
   └── Document prerequisites in the issue body:
       - Which quota/machine types are needed (e.g. "L4 quota confirmed 16 available")
       - Which GCP APIs must be enabled
       - Any reservations or DWS flex-start configs required

2. Confirm prerequisites are in place:
   ├── gcloud quotas info / quota list
   ├── gcloud iam service-accounts list
   └── gcloud services list --enabled

3. When ready to start work:
   └── Remove label: "hold"
   └── Add label:    "overseer"            ← Overseer picks up the issue
       └── RepoWatch creates fix sandbox   ← PR Review dashboard shows it
```

### What `hold` prevents

- **Overseer** only fires on issues with the `overseer` label — not adding it keeps overseer away entirely.
- **RepoWatch** (`fkc1e100/gcp-template-forge`) has `excludeLabels: ["hold"]` on its fix handler — even if a sandbox already exists, no new fix sandboxes are created for issues carrying `hold`.

### When to use `hold`

- Template requires GPU quota (e.g. A100, L4) not yet confirmed
- Template uses DWS / flex-start reservations that need advance setup
- Template requires a dedicated GCP service account to be created first
- Template calls an API (e.g. `gkerecommender.googleapis.com`) that must be enabled before CI runs

---

## Template Structure

```
templates/<short-name>/
├── terraform-helm/
│   ├── main.tf           # resources + empty backend "gcs" {} block
│   ├── variables.tf
│   ├── outputs.tf        # MUST include cluster_name and cluster_location outputs
│   ├── versions.tf       # pin google/google-beta ~> 6.0
│   └── workload/         # Helm chart directory
├── config-connector/
│   ├── *.yaml            # KCC manifests targeting forge-management namespace
│   └── workload/         # Kubernetes manifests for the workload (optional)
├── verification_plan.md  # exact commands to deploy, verify, and destroy both paths
└── README.md             # YOU write descriptive sections; CI appends Validation Record
```

The directory name IS the template identity. Do not prefix with an issue number. Examples: `templates/private-gke-cloud-sql/`, `templates/gke-ray-cluster/`.

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
| **Cluster** | enterprise-gke | krmapihost-kcc-instance |
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
  name                = var.cluster_name  # derived from template name, e.g. "enterprise-gke"
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

Create a **dedicated VPC per template** with unique, non-overlapping CIDRs. Check existing templates before picking ranges to avoid conflicts. Allocate in increments of 16 through the `10.0.0.0/8` space:

| Slot | Primary subnet | Pods secondary | Services secondary | Example template |
|---|---|---|---|---|
| 0 | `10.0.0.0/20` | `10.4.0.0/14` | `10.8.0.0/20` | basic-gke-hello-world |
| 1 | `10.16.0.0/20` | `10.20.0.0/14` | `10.24.0.0/20` | enterprise-gke |
| 2 | `10.32.0.0/20` | `10.36.0.0/14` | `10.40.0.0/20` | gke-llm-inference-gemma |
| 3 | `10.48.0.0/20` | `10.52.0.0/14` | `10.56.0.0/20` | *(next template)* |
| N | `10.(N×16).0.0/20` | `10.(N×16+4).0.0/14` | `10.(N×16+8).0.0/20` | |

Name VPCs and subnets with path-specific suffixes: `<template-name>-tf-vpc` / `<template-name>-tf-subnet` for the Terraform path, and `<template-name>-kcc-vpc` / `<template-name>-kcc-subnet` for the Config Connector path. This ensures the two CI jobs can run in parallel without GCP-level name collisions.

Always use **VPC-native clusters** (`networking_mode = "VPC_NATIVE"` with `ip_allocation_policy`). Always set `private_ip_google_access = true` on subnets.

---

## Machine Types & Accelerators

Use spot/preemptible for all sandbox validation clusters to minimise cost.

| Use case | Machine type | Spot | Notes |
|---|---|---|---|
| General GKE | `e2-standard-4` | ✓ | Default choice |
| Memory intensive | `n2-highmem-4` | ✓ | Databases, caches |
| GPU inference | `g2-standard-12` (L4) | **DWS** | 16 L4s available — see [GPU / AI / ML section](#gpu--ai--ml-templates) |
| GPU inference | `n1-standard-4` (T4) | ✓ | 8 T4s available |
| GPU training | `a2-highgpu-1g` (A100 40GB) | — | Use DWS + Kueue — see [GPU / AI / ML section](#gpu--ai--ml-templates) |
| **❌ DO NOT USE** | `a3-highgpu` (A100 80GB) | — | **Quota = 0, will fail** |
| **❌ DO NOT USE** | `a3-mega` (H100) | — | **Quota = 0, will fail** |

---

## GPU / AI / ML Templates

> **Skip this entire section if your template does not use GPU node pools or serve AI models.** This section covers accelerator provisioning (DWS flex-start), LLM inference tooling, GCS model weight mounting, and Kueue batch scheduling.

### L4 GPU Node Pools: Use DWS Flex-Start, Not Spot

**Do not use `spot = true` for L4 GPU node pools.** Spot VMs are surplus/excess capacity — on-demand requests have first claim on GPU inventory. During scarcity, spot requests fail immediately (`GCE_STOCKOUT`) with no queuing. The problems compound:
1. On-demand physically displaces spot from the capacity pool — spot is structurally last in line
2. L4 spot capacity is chronically thin in us-central1-a and us-central1-b

**Use DWS flex-start instead** (`spot = false` + `queued_provisioning = true`):

```hcl
resource "google_container_node_pool" "gpu_pool" {
  node_config {
    spot         = false  # NOT spot — DWS flex-start is non-preemptible once provisioned
    machine_type = "g2-standard-12"
    ...
  }

  queued_provisioning {
    enabled = true  # spot=false + queued_provisioning=true = DWS flex-start mode
  }
}
```

DWS flex-start draws from the *preemptible* quota pool (which GCP sets larger than standard on-demand quota) but the provisioned VMs are non-preemptible once running. Cost is ~53% below on-demand. GKE queues the request until capacity is available rather than failing immediately — correct for CI validation where a delay is acceptable but a stockout failure is not.

**Zone selection for L4:** `nvidia-l4` / `g2-standard-12` is available in **44 zones across 19 global regions**. Best headroom within us-central1 is zone `-c`. If stockouts persist, expand `node_locations` to include zones in `us-east1`, `europe-west4`, or `asia-southeast1` — all have 3 L4-capable zones. Restrict `node_locations` to a single zone to reduce scheduling spread and improve fill rate: `node_locations = ["${var.region}-c"]`.

### Scarce Accelerators: Use DWS + Kueue

For A100/A2 node pools and v5e/v6e TPU slices, **Dynamic Workload Scheduler (DWS) + Kueue** is required. DWS queues the workload and provisions capacity when GCP has it — validation may take hours or up to a week for highly contested hardware.

**When to use DWS + Kueue:**
- Any A2 (A100) node pool
- Any TPU v5e/v6e slice node pool
- Any accelerator where quota headroom is <50%

**How to configure — all three fields are required simultaneously:**

```hcl
resource "google_container_node_pool" "gpu_pool" {
  # REQUIRED for DWS: autoscaling block — do NOT use node_count alongside autoscaling
  autoscaling {
    min_node_count = 0
    max_node_count = 1
  }

  node_config {
    spot         = false  # REQUIRED: DWS flex-start is non-preemptible
    machine_type = "g2-standard-12"

    # REQUIRED: DWS cannot use reservations
    reservation_affinity {
      consume_reservation_type = "NO_RESERVATION"
    }
    # ... rest of node_config
  }

  # REQUIRED: enables the DWS queue
  queued_provisioning {
    enabled = true
  }
}
```

**Omitting any one of `autoscaling`, `reservation_affinity NO_RESERVATION`, or `spot = false` causes a GKE API 400 error.**
**Never use `node_count` alongside `autoscaling {}` — they are mutually exclusive.**

```bash
# Install Kueue operator — use the public HTTPS repo (OCI endpoint requires GCP auth in CI)
helm install kueue kueue/kueue \
  --repo https://charts.kueue.sigs.k8s.io \
  --version 0.9.1 --namespace kueue-system --create-namespace
```

Required Kueue resources: `ClusterQueue` → `ResourceFlavor` → `LocalQueue`. Workload pods need label `kueue.x-k8s.io/queue-name: <local-queue-name>`.

Reference: `github.com/GoogleCloudPlatform/accelerated-platforms` — check the DWS examples.

**Validation timeouts — DWS provisioning time varies significantly by hardware:**
- **L4 flex-start** (`g2-standard-12`): typically **20–30 minutes** once the request is queued
- **A100/A2 DWS + Kueue**: **hours to 7 days** depending on regional contention

In `verification_plan.md`, document the expected wait and how to monitor: `kubectl get workloads -n <namespace>`. Use `--timeout=1800s` (30 min) for GPU cluster `kubectl wait` commands — 600s is too short for GPU node pool provisioning.

### GKE Inference Quickstart

For templates that serve **pre-trained AI models** (LLM inference, image generation, embedding serving), use the **GKE Inference Quickstart** tool (`gcloud container ai profiles`) to generate performance-tuned cluster and workload designs before writing any Terraform or manifests.

**Why**: The quickstart benchmarks model-hardware combinations and emits validated Kubernetes manifests (Deployment, Service, HPA, PodMonitoring) with correct resource requests, GPU configuration, and model-server flags. Starting from these avoids hours of trial-and-error sizing.

**Available in the sandbox**: `gcloud` (≥ 536.0.1) with the `gke-gke-extension`, `gh` CLI (authenticated via the `github-token` secret), `terraform`, `helm`, `kubectl`, and `curl` are all pre-installed and authenticated. The GitHub MCP server also provides structured read access to GitHub repositories — use it or `gh api` for reference file fetching. Run all commands directly without any setup.

**Key commands**:

```bash
# 1. List supported models and use-cases
gcloud container ai profiles use-cases list

# 2. View benchmark data for a model across all available accelerators
gcloud container ai profiles benchmarks list \
  --filter="modelId:<model-id>"

# 3. Generate deployment manifests using the accelerator selected from step 2
gcloud container ai profiles manifests create \
  --use-case=<use-case-id> \
  --accelerator-type=<accelerator-from-benchmarks> \
  --output-path=./workload/
```

**Flags of interest**:
- `--accelerator-type` — GPU type selected from benchmark output (e.g., `nvidia-l4`, `nvidia-tesla-t4`)
- `--target-ttft-milliseconds` — Time to First Token latency target
- `--target-ntpot-milliseconds` — Next Token per Output Token latency target
- `--model-bucket-uri` — Cloud Storage URI of the model weights (if self-hosted)

**Supported model families**: Gemma, Llama, Mistral, DeepSeek, Qwen (check `use-cases list` for the current full list).

**Model servers**: The quickstart generates configs for **vLLM** (default) and **llm-d** (distributed inference across multiple nodes). The Helm registry for the GKE Inference Gateway / vLLM stack is `oci://us-docker.pkg.dev/ml-serving-discovery/helm`.

**Workflow**:
1. Run `gcloud container ai profiles use-cases list` to find the right use-case for the requested model.
2. Run `gcloud container ai profiles benchmarks list --filter="modelId:<model>"` to see benchmark data (throughput, TTFT, NTPOT, cost) across all accelerator options. **Select the accelerator from this output** — do not pre-decide the GPU type before running this command.
3. Run `gcloud container ai profiles manifests create` using the accelerator chosen in step 2. The generated manifests specify the GPU type, count, resource requests, and model-server flags — these are the authoritative source for hardware selection.
4. Use the generated manifests as the baseline for the template's `workload/` directory — **do not write GPU/model-server configs from scratch**.
5. **Build the node pool to match the accelerator type and replica count from the generated manifests.** The manifest output drives the cluster spec, not prior assumption.

**Note on quota**: H100 quota is 0 in this sandbox — do not request H100. If the benchmark output recommends H100, select the next best available option from the benchmark list.

**Required README section for inference templates**: Every inference template README must include a `## Performance & Cost Estimates` section populated from the benchmark output:

```markdown
## Performance & Cost Estimates

*Generated from `gcloud container ai profiles benchmarks list`*

| Metric | Value |
|---|---|
| Model | <from benchmarks output> |
| Accelerator | <from benchmarks output> |
| Time to First Token (p50) | <from benchmarks output> |
| Next Token Output Token (p50) | <from benchmarks output> |
| Throughput | <from benchmarks output> |
| Node type | <from manifests output> |
| Estimated node cost | ~$X.XX/hr |
| Estimated cost per 1M tokens | ~$X.XX |
```

Do not fabricate these numbers. Run the benchmarks command and use the actual output.

### GCS FUSE CSI Driver

For templates that mount GCS buckets as volumes (e.g., model weights for LLM inference), the **GCS FUSE CSI driver must be explicitly enabled** on the cluster. Without it, pod `volumeMount` against a `csi` volume with driver `gcsfuse.csi.storage.gke.io` will silently fail to mount.

```hcl
resource "google_container_cluster" "primary" {
  # ...
  addons_config {
    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }
}
```

The pod's ServiceAccount must also have `roles/storage.objectViewer` (read) and optionally `roles/storage.objectCreator` (write for init containers that populate the bucket). Grant these via `google_storage_bucket_iam_member`, not `google_project_iam_member`.

### Local Kueue Chart Structure

When using a local chart for Kueue queue resources (ResourceFlavor, ClusterQueue, LocalQueue), the chart must have this minimal structure:

```
kueue-chart/
├── Chart.yaml
└── templates/
    └── queues.yaml
```

`Chart.yaml`:
```yaml
apiVersion: v2
name: kueue-resources
description: Kueue queue resources for GPU template
type: application
version: 0.1.0
```

`templates/queues.yaml`:
```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: gpu-flavor
spec:
  nodeLabels:
    cloud.google.com/gke-accelerator: nvidia-l4
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: gpu-cluster-queue
spec:
  namespaceSelector: {}
  resourceGroups:
    - coveredResources: ["cpu", "memory", "nvidia.com/gpu"]
      flavors:
        - name: gpu-flavor
          resources:
            - name: "nvidia.com/gpu"
              nominalQuota: 1
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  name: gpu-local-queue
  namespace: <workload-namespace>
spec:
  clusterQueueName: gpu-cluster-queue
```

Workload pods must include the label `kueue.x-k8s.io/queue-name: gpu-local-queue` to be admitted through the queue.

---

## Required README Section: Performance & Cost Estimates (All Templates)

**Every template README** must include a `## Performance & Cost Estimates` section. This applies to all template types — not just inference.

For **inference templates**, populate from `gcloud container ai profiles benchmarks list` (see above).

For **all other templates**, estimate from GCP pricing using the resources the template provisions:

```bash
# List machine type pricing in the deployment region
gcloud compute machine-types describe <machine-type> --zone=us-central1-a --format="value(description)"

# Use gcloud billing to check current SKU prices if needed
gcloud billing catalogs list-skus --service=services/6F81-5844-456A  # GKE service ID
```

The section must cover at minimum:
- Node pool machine type and count, with hourly cost
- Whether spot/preemptible is used and the discount applied
- Any persistent storage costs (PD, Filestore, GCS)
- Estimated **monthly cost at idle** and **monthly cost under load**

Example for a standard GKE template:

```markdown
## Performance & Cost Estimates

| Resource | Spec | Est. Cost |
|---|---|---|
| Control plane | GKE Autopilot / Standard | ~$0.10/hr |
| Node pool | e2-standard-4 × 2 (spot) | ~$0.08/hr per node |
| Boot disk | 100 GB pd-balanced × 2 | ~$0.02/hr |
| **Total (idle, 2 nodes)** | | **~$0.28/hr (~$200/mo)** |
```

Do not fabricate costs. Use `gcloud` or the [GCP Pricing Calculator](https://cloud.google.com/products/calculator) and cite the source.

> **Note**: `gcloud container ai profiles manifests create` calls `gkerecommender.googleapis.com` and requires authentication. The sandbox WIF credentials cover this automatically — the SA is `forge-sandbox@gca-gke-2025.iam.gserviceaccount.com`.

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

# 2. Check your machine type is available in zone (replace <machine-type> with the actual type)
gcloud compute machine-types list \
  --filter="zone:us-central1-b AND name=<machine-type>" \
  --format="table(name,zone)"

# 3. GPU / AI / ML templates only — check accelerator availability
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

### GKE Security Posture

All clusters must include a `security_posture_config` block. Use `VULNERABILITY_BASIC` for Autopilot, `VULNERABILITY_ENTERPRISE` for Standard:

```hcl
security_posture_config {
  mode               = "BASIC"
  vulnerability_mode = "VULNERABILITY_BASIC"   # or VULNERABILITY_ENTERPRISE for Standard clusters
}
```

For KCC manifests, the equivalent is:

```yaml
securityPostureConfig:
  mode: BASIC
  vulnerabilityMode: VULNERABILITY_BASIC
```

### ⚠️ Helm Chart CRDs — Must go in `crds/` not `templates/`

If your Helm workload chart includes CRD definitions, place them in the chart's `crds/` subdirectory, **not** in `templates/`. Helm treats `crds/` differently:

- CRDs in `crds/` are installed before templates and **skipped without error if they already exist**
- CRDs in `templates/` are tracked with ownership annotations — if GKE installed the same CRD natively (e.g. via `secret_manager_config { enabled = true }` which auto-installs the Secrets Store CSI driver), Helm will fail with an ownership conflict

Files in `crds/` are raw YAML, not Go templates — no `{{- if ... }}` conditionals.

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

## ⚠️ Terraform Correctness: Mandatory Checks Before Every Commit

CI runs `terraform fmt -check -recursive` and `terraform validate` on every push. **A single lint failure blocks the entire pipeline — deploy jobs never run.** Do not push until all three steps below pass locally.

```bash
cd templates/<name>/terraform-helm

# ── STEP 1: Duplicate declaration scan ──────────────────────────────────────
# All .tf files in the same directory share one module namespace.
# Any duplicate resource/variable/output/local is a compile error.
# This must print NOTHING. If it prints anything, fix it before continuing.
grep -rh '^\s*resource\|^\s*variable\|^\s*output\|^\s*locals' *.tf \
  | grep -v '^\s*#' \
  | sort | uniq -d

# ── STEP 2: Format check ─────────────────────────────────────────────────────
terraform fmt -check -recursive
# If this exits non-zero, run: terraform fmt -recursive   (auto-fixes alignment)
# Then re-stage and re-run the check.

# ── STEP 3: Structural validation ───────────────────────────────────────────
terraform validate
# Catches bad references, wrong types, and any duplicates the grep missed.
```

**All three steps must exit 0 before you `git push`.**

### Rule: no repetition across `.tf` files — read before you write

Every `.tf` file in `terraform-helm/` is part of the **same Terraform root module**. There is no isolation between files. Before declaring any `resource`, `variable`, `output`, or `local`:

1. **Read every existing `.tf` file** in the directory to know what is already declared.
2. **Grep for the name** you are about to use: `grep -r '"my_resource_name"' *.tf`
3. If it exists anywhere — in any file — **do not declare it again**. Reference the existing declaration or extend it.

Declarations that trip up agents most often:

| What gets duplicated | How it happens | How to avoid |
|---|---|---|
| `resource "helm_release" "kueue_resources"` | Added to `main.tf` after `kueue.tf` already owned it | Read `kueue.tf` first; extend it instead |
| `variable "project_id"` | Declared in both `variables.tf` and a new module file | All vars live in `variables.tf` only |
| `output "cluster_name"` | Copied from another template without checking | Read `outputs.tf` before adding |
| `resource "google_storage_bucket" "weights"` | Added twice when refactoring across files | Step 1 grep catches this |

### Rule: all `=` signs in a resource block must align

`terraform fmt` aligns every `=` to the column after the longest key in the block, with exactly one space. If you add a key that is longer than all existing keys, **every other key in the block needs more padding** — not just the new one.

```hcl
# ✅ correct — longest key is "create_namespace" (16 chars), all = aligned
resource "helm_release" "example" {
  name             = "example"
  chart            = "${path.module}/chart"
  namespace        = "default"
  create_namespace = true
  depends_on       = [google_container_node_pool.pool]
}

# ❌ wrong — adding "create_namespace" without re-padding the shorter keys
resource "helm_release" "example" {
  name = "example"           # too short — fmt will flag this
  create_namespace = true
}
```

**The safest fix is always: run `terraform fmt -recursive` and commit the result rather than hand-padding.**

### Rule: one file owns one concern

Do not split a logical unit across files. If `kueue.tf` owns the Kueue operator and its queue resources, all changes to those resources go in `kueue.tf` — not in `main.tf`. When you are unsure which file owns something, read all `.tf` files first, then decide.

---

## Helm Chart Sources

### Prefer public HTTP repos over OCI registries

OCI Helm registries (e.g. `oci://us-docker.pkg.dev/...`) may require GCP authentication that GitHub Actions runners do not have by default. The CI runner authenticates via WIF for `gcloud`/Terraform, but that authentication does **not** automatically extend to `helm pull` from Artifact Registry OCI endpoints.

**Prefer in this order:**

| Priority | Source | Example |
|---|---|---|
| 1 | **Local chart in repo** | `chart = "${path.module}/my-chart"` |
| 2 | **Public HTTPS Helm repo** | `repository = "https://charts.example.io"` |
| 3 | **Public OCI registry** | `oci://registry.k8s.io/...` (k8s.io is unauthenticated) |
| 4 | **GCP Artifact Registry OCI** | `oci://us-docker.pkg.dev/...` — **avoid unless you add explicit auth** |

**For a standard public HTTPS chart** (e.g., ingress-nginx, cert-manager, external-dns):

```hcl
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.10.0"
  namespace        = "ingress-nginx"
  create_namespace = true
}
```

**For Kueue specifically** (GPU / AI / ML templates): install the operator from the official public chart, then use a local chart for your `ResourceFlavor` / `ClusterQueue` / `LocalQueue` objects:

```hcl
# Kueue operator — use public HTTPS repo, not the GCP OCI endpoint
resource "helm_release" "kueue" {
  name             = "kueue"
  repository       = "https://charts.kueue.sigs.k8s.io"
  chart            = "kueue"
  version          = "0.9.1"
  namespace        = "kueue-system"
  create_namespace = true
}

# Queue resources — always local chart
resource "helm_release" "kueue_resources" {
  name             = "kueue-resources"
  chart            = "${path.module}/kueue-chart"
  namespace        = "kueue-system"
  create_namespace = true
  depends_on       = [helm_release.kueue, google_container_node_pool.gpu_pool]
}
```

---

## KCC Manifests

All KCC resources go into the `forge-management` namespace on `krmapihost-kcc-instance`. Label every resource with the template directory name so CI can target it:

```yaml
metadata:
  namespace: forge-management
  labels:
    template: templates/my-template
  # annotations:
  #   cnrm.cloud.google.com/deletion-policy: abandon  ← NEVER
```

Annotate with the project: `cnrm.cloud.google.com/project-id: gca-gke-2025`.

### ⚠️ KCC Deletion Order — Critical

**Never delete a GKE cluster directly via `gcloud container clusters delete` while its KCC `ContainerCluster` resource still exists.** Config Connector reconciles continuously — if the GCP cluster disappears, KCC will immediately re-provision it (typically within 8 minutes).

Always delete in this order:
1. `kubectl delete containerclusters.container.cnrm.cloud.google.com <name> -n forge-management --wait=false`
2. Wait for the GKE cluster to reach `STOPPING` status: `gcloud container clusters list --filter="name=<name>"`
3. Only then confirm the cluster is fully gone — do not `gcloud delete` directly

This applies to orphan cleanup scripts as well as manual teardown.

---

## Reference Repositories

> **See the [Mandatory Design Research](#mandatory-design-research) section above for the exact `gh api` fetch commands to run before writing any code.** The table below is the full catalogue; the Design Research section gives you the specific files and commands for each template type.

Before writing code, fetch real examples from the most relevant upstream repos. Use `gh` CLI or the GitHub MCP server (both are available in the sandbox):

```bash
# Browse a directory
gh api repos/<owner>/<repo>/contents/<path> --jq '.[].name'

# Fetch and decode a specific file
gh api repos/<owner>/<repo>/contents/<path> --jq '.content' | base64 -d
```

Key sources:
- **Terraform GKE module** — `terraform-google-modules/terraform-google-kubernetes-engine` (`examples/` dir)
- **KE Samples** — `GoogleCloudPlatform/kubernetes-engine-samples` (workload manifests)
- **AI on GKE** — `ai-on-gke/tutorials-and-examples` (GPU/LLM patterns)
- **Accelerated Platforms** — `GoogleCloudPlatform/accelerated-platforms` (GPU cluster blueprints, DWS examples)
- **Cloud Foundation Toolkit** — `GoogleCloudPlatform/cloud-foundation-toolkit` (VPC, IAM modules)
- **LLM-D** — `llm-d/llm-d` (distributed LLM inference on GKE)
- **GKE AI Labs** — `gke-ai-labs.dev` (AI/ML on GKE patterns and benchmarks)
- **GKE Policy Automation** — `google/gke-policy-automation` (policy as code)
- **Config Connector Samples** — `GoogleCloudPlatform/k8s-config-connector` (`config/samples/resources/`) — authoritative KCC YAML for every GCP resource type

See `user-instructions.json` → `reference_repositories` for the full list.

### When to search the web

**Do not guess at API behaviour, error codes, or resource constraints — search first.**

If you hit an unfamiliar error, a quota limit, a GKE API validation failure, or any situation where the correct configuration is not obvious from the code or GEMINI.md guidance, **stop and research it before writing a fix**. Use web search or fetch public documentation:

```bash
# Fetch GCP/GKE documentation pages directly
curl -s "https://cloud.google.com/kubernetes-engine/docs/how-to/node-pools" | \
  python3 -c "import sys,html,re; print(re.sub('<[^>]+>','',html.unescape(sys.stdin.read())))" | head -200

# Search GitHub issues for known errors
gh search issues "queued_provisioning requires autoscaling" --repo hashicorp/terraform-provider-google

# Fetch raw source from a reference repo
gh api repos/GoogleCloudPlatform/accelerated-platforms/contents/platforms/gke/base/cluster/node-pools/dws \
  --jq '.content' | base64 -d
```

**Priority research targets by error type:**

| Error type | Where to look |
|---|---|
| GKE API 400 / node pool validation | [GKE node pool docs](https://cloud.google.com/kubernetes-engine/docs/how-to/node-pools) + `terraform-provider-google` GitHub issues |
| DWS / queued provisioning config | [DWS docs](https://cloud.google.com/kubernetes-engine/docs/how-to/provisioningrequest) + `GoogleCloudPlatform/accelerated-platforms` |
| Helm / OCI registry 403 | Helm GitHub issues + chart's own repo for auth requirements |
| GPU driver / accelerator errors | [GKE GPU docs](https://cloud.google.com/kubernetes-engine/docs/how-to/gpus) + `GoogleCloudPlatform/kubernetes-engine-samples/gpu` |
| vLLM / inference server config | [vLLM docs](https://docs.vllm.ai) + `vllm-project/vllm` GitHub issues |
| Secret Manager IAM | [Secret Manager IAM docs](https://cloud.google.com/secret-manager/docs/access-control) |
| Kueue config / CRDs | [Kueue docs](https://kueue.sigs.k8s.io/docs/) + `kubernetes-sigs/kueue` |

**After finding a fix from web research, append a bullet to `## Agent-Discovered Fixes`** so the next agent doesn't have to repeat the same search.

---

## Agent Metrics Reporting

Before opening the PR, write a `.agent-metrics` file to the template root. The CI reads this to populate the token/cost row in the Validation Record. Use your best estimate of total tokens consumed across the whole session for the issue.

```bash
cat > templates/<name>/.agent-metrics <<EOF
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
| PR created | Link to PR (`Closes #N` already in PR body — no need to repeat in comment) |
| CI outcome | Pass with timings, or failure with diagnosis and intended fix |

**PR body must always contain `Closes #<issue-number>`** — this links the PR to the issue in GitHub's Development panel. Do not omit it.

---

## Validation Checklist (KCC)

- [ ] `kubectl wait --for=condition=Ready` on all applied KCC CRs — **use `--timeout=1800s` for GPU clusters; 600s is too short for GPU node pool provisioning (15–25 min)**
- [ ] Drift and revert: mutate a resource out-of-band → verify KCC reverts it
- [ ] Workload Identity integration: deploy a Job to verify pod can access KCC-created resources
- [ ] Teardown: `kubectl delete` KCC resource first → wait for GCP cluster to reach STOPPING → confirm gone via `gcloud` (never `gcloud delete` directly while KCC resource exists — see KCC Deletion Order above)

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
| LLM inference | **Wait for model to load first** (pod Ready ≠ model ready — vLLM takes 5–15 min after pod Running to load weights). Poll `GET /health` until HTTP 200, then send a test prompt and verify a generated response. |

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
| Per-template VPC, not `forge-network` | forge-network has no GKE-compatible secondary ranges |
| Pre-check quotas before apply | Prevents failed deployments that waste sandbox time |
| Use DWS + Kueue for A100/TPU | Only way to get scarce accelerators without hardcoded reservations |
| Spot/preemptible for **CPU** validation nodes | Reduces sandbox cost by ~60–80%; **exception: GPU node pools — use DWS flex-start (`spot = false` + `queued_provisioning = true`) — spot puts GPU requests at the back of the capacity queue and fails immediately on stockout** |
| Pin provider versions `~> 6.0` | Prevents unexpected breaking changes on re-runs |
| Empty `backend "gcs" {}` block | CI injects state location; hardcoding causes conflicts |
| Issue comments at every checkpoint | Visibility for human reviewers; catch problems early |
| **Never create `.github/workflows/` files** | `sandbox-validation.yml` is the only CI workflow — do not add `ci.yaml` or any other workflow. Extra workflows break CI with missing-secret errors (`GCP_SA_KEY`, `GKE_CLUSTER_NAME` do not exist; auth is WIF-only). |
| No hardcoded project/SA defaults in `variables.tf` | Templates are published for external use; CI injects values via `TF_VAR_project_id` and `TF_VAR_service_account` — leave both as required variables with no default |
| **Update `## Agent-Discovered Fixes` for non-obvious errors** | Append one bullet when you fix a quota, IAM, machine-sizing, or API auth issue not already documented — prevents the next agent hitting the same wall |

---

## Agent-Discovered Fixes

**Append here when you fix a non-obvious error not already documented above.** One bullet per issue. Include the symptom, the fix, and why it happened so future agents can recognise the pattern.

Format: `- **[area]** symptom → fix. (root cause)`

---

- **GPU node pools (L4)** `g2-standard-48` with 4×L4 enters ERROR state after ~45 min → use `g2-standard-12` with 1×L4 and set `tensorParallelSize: 1` in values.yaml. (Spot availability and quota for large multi-GPU machines is thin in us-central1; 1×L4 on g2-standard-12 is sufficient for 9B-parameter models and provisions reliably.)

- **WIF binding via Terraform** `google_service_account_iam_member` targeting the CI service account returns 403 during `terraform apply` → remove the resource entirely; do not attempt to set Workload Identity bindings on the CI SA from within the template. (The `forge-builder` SA lacks `iam.serviceAccounts.getIamPolicy` on itself; the binding already exists in the project and re-applying it via Terraform is both unnecessary and unauthorised.)

- **Duplicate Terraform resource** `terraform validate` fails with `Duplicate resource … configuration` at lint → grep all `.tf` files in the directory for the resource name before declaring it. All files in `terraform-helm/` share the same module namespace; declaring the same resource in `main.tf` and `kueue.tf` is a compile error. Reference the existing resource instead of re-declaring it.

- **CI fails with OIDC / WIF 403 on "Authenticate to GCP" + github-script 403 on comment** → the PR was opened from the fork (`codebot-sfle/gcp-template-forge`) instead of the upstream. WIF OIDC tokens are blocked for forked PRs by GitHub's security model — this is not a code problem. Fix: push the branch to upstream and reopen the PR from there.
  ```bash
  git push upstream HEAD
  # Close the fork-based PR with a comment, then:
  gh pr create --repo fkc1e100/gcp-template-forge \
    --head "$(git rev-parse --abbrev-ref HEAD)" \
    --title "<same title>" --body "Closes #<issue> ..."
  ```

- **OCI Helm registry 403 in CI** `helm_release` pointing to `oci://us-docker.pkg.dev/gke-release-packages/helm-charts/kueue` returns HTTP 403 during `terraform apply` → switch to the public HTTPS Helm repo (`repository = "https://charts.kueue.sigs.k8s.io"`). The WIF credentials the CI runner uses for `gcloud` do not automatically authenticate `helm` against Artifact Registry OCI endpoints.

- **DWS node pool config** `google_container_node_pool` with `queued_provisioning { enabled = true }` fails with API 400 → three fields are required simultaneously: (1) `autoscaling { min_node_count = 0, max_node_count = N }` — do not use `node_count`; (2) `reservation_affinity { consume_reservation_type = "NO_RESERVATION" }` inside `node_config`; (3) `spot = false` — DWS flex-start is not compatible with spot. Missing any one of these causes the node pool creation to be rejected.

- **Secret Manager IAM via Terraform** `google_secret_manager_secret_iam_member` targeting a pre-existing secret (e.g., `huggingface-token`) fails with 403 during `terraform apply` → remove the resource; grant `roles/secretmanager.secretAccessor` to the workload SA out-of-band via `gcloud secrets add-iam-policy-binding`. The CI SA has `secretAccessor` to *read* secrets but lacks `secretmanager.secrets.getIamPolicy` needed to *manage* IAM on them. Do not attempt to set IAM on pre-existing secrets from within the template.

- **L4 GPU spot → GCE_STOCKOUT** `spot = true` on `g2-standard-12` node pools in us-central1-a/b fails with `GCE_STOCKOUT` — 0 nodes provisioned after 35 min → switch to DWS flex-start: set `spot = false` and keep `queued_provisioning { enabled = true }`. Spot VMs are surplus capacity; on-demand has first physical claim on GPU inventory, so spot requests fail outright during scarcity with no queue. DWS flex-start draws from the larger preemptible quota pool and is non-preemptible once running (~53% below on-demand cost). Also restrict `node_locations` to `["${var.region}-c"]` — us-central1-c has the best L4 headroom within the region. L4 is available globally across 44 zones in 19 regions (us-central1, us-east1, europe-west4, asia-southeast1, and more) — expand zones if us-central1-c stockouts persist.
