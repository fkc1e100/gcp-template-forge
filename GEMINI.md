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

