# GCP Template Forge

> An AI-driven pipeline that designs, deploys, and validates production-ready GKE reference architectures — dual-path (Terraform + Helm and Config Connector) — with every merge.

## Objectives

1. **Design** — Use an AI agent (Gemini CLI + Claude) to author complete, enterprise-grade IaC templates from Google Cloud reference architectures, covering both Terraform/Helm and Config Connector deployment paths.
2. **Deploy & Test** — Run every template through a full apply → verify → destroy cycle in a real GCP sandbox project before any PR is merged, and again after merge to confirm the published artifact works end-to-end.
3. **Consolidate** — Act as a living, continuously-validated library of GKE patterns drawn from Google Cloud's public reference repositories, so teams can adopt them with confidence.

---

## System Architecture

The forge is powered by the operator stack from [`gke-labs/gemini-for-kubernetes-development`](https://github.com/gke-labs/gemini-for-kubernetes-development), running on a GKE Standard control-plane cluster. Each new template request flows through four components:

```mermaid
graph TD
    subgraph "gke-labs Operator Stack (Control Plane GKE Cluster)"
        OV["🎯 Overseer\nMonitors GitHub issues & PRs\nCoordinates the full workflow"]
        RA["📋 Repo-Agent\nManages GitHub operations\n(create issue, branch, PR)"]
        AS["🤖 AgentSandboxes\nIsolated Kubernetes Jobs\nwhere Gemini CLI runs"]
        CR["📦 Container Registry\nAgent container images"]
    end

    subgraph "GitHub (fkc1e100/gcp-template-forge)"
        ISS["📝 Issue\n'Template request'"]
        BR["🌿 Branch\nissue-N-<slug>"]
        PR["🔀 Pull Request\nTemplate + CI checks"]
        MAIN["✅ main branch\nValidated templates"]
    end

    subgraph "GCP Sandbox Project (gca-gke-2025)"
        KCC["☸️ KCC Cluster\nkrmapihost-kcc-instance\nConfig Connector resources"]
        TF["🏗️ Terraform Resources\nVPC · GKE · NAT · IAM"]
        HELM["⎈ Helm Workloads\nDeployed to Terraform cluster"]
    end

    USER["👤 Developer\nopens GitHub issue"] --> ISS
    ISS --> OV
    OV --> RA
    RA --> BR
    OV --> AS
    AS --> CR
    AS -- "commits template files" --> BR
    BR --> PR
    PR -- "CI: lint + deploy-and-test" --> TF
    PR -- "CI: lint + deploy-and-test" --> KCC
    TF --> HELM
    PR -- "approved + merged" --> MAIN
    MAIN -- "CI: validate-and-publish" --> TF
    MAIN -- "CI: validate-and-publish" --> KCC
    MAIN -- "updates README + .validated" --> MAIN
```

### Key Components

| Component | Role | Repo |
|---|---|---|
| **Overseer** | Kubernetes operator that watches GitHub for new issues, coordinates the agent lifecycle, and manages PR state | [`gke-labs/gemini-for-kubernetes-development`](https://github.com/gke-labs/gemini-for-kubernetes-development) |
| **Repo-Agent** | Creates GitHub issues, branches, and PRs; posts status comments; triggers the agent sandbox | same |
| **AgentSandboxes** | Kubernetes Jobs that spin up an isolated Gemini CLI session per template; the agent authors all IaC files and commits them | same |
| **forge-builder SA** | GCP service account used by GitHub Actions CI to authenticate and run Terraform/Helm/KCC against the sandbox project | `agent-infra/` |

---

## Design → Deploy → Test Flow

Each template goes through two separate CI gate points:

```mermaid
sequenceDiagram
    actor Dev as Developer / Overseer
    participant GH as GitHub
    participant CI as GitHub Actions
    participant GCP as GCP Sandbox

    Dev->>GH: Open issue (template request)
    GH->>CI: Overseer creates branch + triggers AgentSandbox
    CI->>GH: Agent commits terraform-helm/ + config-connector/

    Note over GH,CI: Pull Request CI Gate
    GH->>CI: PR opened → sandbox-validation.yml triggers
    CI->>CI: detect-changes (PR head SHA diff)
    CI->>CI: lint: tf fmt/validate · helm lint · KCC YAML · both-paths check
    CI->>GCP: deploy-and-test: terraform apply
    GCP-->>CI: cluster RUNNING ✓
    CI->>GCP: helm upgrade --install
    GCP-->>CI: workload ready ✓
    CI->>GCP: terraform destroy
    CI->>GCP: kubectl apply (KCC manifests)
    GCP-->>CI: KCC resources Ready ✓
    CI->>GCP: kubectl delete (KCC teardown)
    CI->>GH: Post deploy summary to PR
    Dev->>GH: Review + merge PR

    Note over GH,CI: Post-Merge CI Gate
    GH->>CI: push to main → validate-and-publish triggers
    CI->>CI: skip-check (has template changed since .validated?)
    CI->>GCP: terraform apply (full re-deploy)
    GCP-->>CI: cluster RUNNING ✓
    CI->>GCP: terraform destroy
    CI->>GCP: KCC apply + wait Ready
    CI->>GCP: KCC delete
    CI->>GH: Commit updated README.md + .validated marker
```

### Template CI Lifecycle

```
templates/<name>/
├── terraform-helm/         ← Terraform + Helm deployment path
│   ├── main.tf             ← VPC · cluster · workload resources
│   ├── variables.tf
│   ├── versions.tf         ← pinned provider versions + GCS backend
│   ├── outputs.tf          ← cluster_name, cluster_location (required by CI)
│   └── workload/           ← Helm chart for the workload
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
├── config-connector/       ← Config Connector (KCC) deployment path
│   ├── network.yaml        ← ComputeNetwork + ComputeSubnetwork
│   └── cluster.yaml        ← ContainerCluster (+ NodePool if standard)
├── README.md               ← auto-updated by CI with validation record
└── .validated              ← CI marker: commit + status written after successful deploy
```

**CI enforcement rules:**
- Both `terraform-helm/` and `config-connector/` must exist (lint fails otherwise)
- `google_container_cluster` must have `deletion_protection = false`
- KCC manifests must not use `cnrm.cloud.google.com/deletion-policy: abandon`
- Resources must use template-based names (e.g., `enterprise-gke-vpc`) not issue numbers
- `validate-and-publish` re-runs whenever the template changes after its last `.validated` commit

---

## Templates

| # | Template | TF+Helm | KCC | Validated |
|---|---|---|---|---|
| 1 | [basic-gke-hello-world](templates/1-basic-gke-hello-world/) | GKE Autopilot + hello-world | GKE Autopilot | — |
| 6 | [enterprise-gke](templates/6-enterprise-gke/) | GKE Standard + security stack + Helm workload | GKE Standard + networking | — |

---

## Repository Structure

```
.github/
  workflows/
    sandbox-validation.yml  ← lint · deploy-and-test (PR) · validate-and-publish (push)
  ISSUE_TEMPLATE/           ← template request form
agent-infra/
  terraform/                ← control-plane GKE cluster + forge-builder SA
  manifests/                ← Overseer + Repo-Agent + AgentSandboxes deployments
templates/
  1-basic-gke-hello-world/
  6-enterprise-gke/
GEMINI.md                   ← guardrails and instructions for the Gemini CLI agent
GUIDANCE.md                 ← manual setup steps (identity, Secret Manager)
```

---

## Public Reference Sources

The forge validates patterns drawn from:

| Source | Focus |
|---|---|
| [Cloud Foundation Toolkit](https://github.com/GoogleCloudPlatform/cloud-foundation-toolkit) | GCP security baselines |
| [Cluster Toolkit](https://github.com/GoogleCloudPlatform/cluster-toolkit) | HPC + AI/ML clusters |
| [Kubernetes Engine Samples](https://github.com/GoogleCloudPlatform/kubernetes-engine-samples) | GKE workload patterns |
| [Terraform GKE Modules](https://github.com/terraform-google-modules/terraform-google-kubernetes-engine) | Reusable TF modules |
| [GKE AI Labs](https://gke-ai-labs.dev/) | AI/ML on GKE |
| [Gemini for Kubernetes Development](https://github.com/gke-labs/gemini-for-kubernetes-development) | Operator stack powering this forge |
| [Accelerated Platforms](https://github.com/GoogleCloudPlatform/accelerated-platforms) | GPU/TPU workloads |
| [GKE Policy Automation](https://github.com/google/gke-policy-automation) | Policy as code |
| [LLM-D](https://github.com/llm-d/llm-d) | LLM inference on GKE |
