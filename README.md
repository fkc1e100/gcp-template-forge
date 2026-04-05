# GKE Template Forge

Automated pipeline to translate natural language intent from GitHub Issues into validated and security-scanned Infrastructure as Code (Terraform, Helm, Config Connector) templates.

## Overview
This project implements an agentic orchestration layer on GKE to automate the generation and validation of Kubernetes architectures. It listens for feature requests or architecture descriptions in GitHub Issues, uses `repo-agent` and `overseer` (from `gemini-for-kubernetes-development`) to generate the corresponding IaC, validates it in a sandbox project, and publishes the results as reusable templates.

## Architecture
- **Control Plane:** GKE Standard cluster hosting `repo-agent` and `overseer`.
- **Infrastructure as Code:** Terraform for base infra, Helm and Config Connector for workloads.
- **Validation:** Automated sandbox execution and security scanning.

## Current Status
- [x] Initial repository scaffolding established.
- [x] Agent infrastructure drafted and validated with Terraform.
- [x] External agent manifests organized and updated with inferred images.
- [x] Remote repository created and code pushed.
- [ ] **Pending:** Manual secret provisioning in GCP Secret Manager to enable deployment.

## Next Steps
To complete the setup and deploy the infrastructure, please refer to the manual intervention steps detailed in [GUIDANCE.md](GUIDANCE.md) regarding GitHub App creation and Secret Manager configuration.

The desired bot identity for this project is **`forgebot-robot`**.

## Repository Structure
- `.github/`: Issue templates and GitHub Actions workflows.
- `agent-infra/`: Terraform code for cluster and manifests for agents.
- `templates/`: Destination for successfully validated templates.
