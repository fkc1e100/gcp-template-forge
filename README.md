# GCP Template Forge

## Overview
GCP Template Forge is an automated pipeline and orchestration framework designed to generate, test, deploy, and validate Infrastructure as Code (IaC) templates for full-stack application environments. Rather than starting from scratch, this repository focuses on aggregating, building out, and rigorously validating publicly available Google Cloud reference architectures to ensure they deploy successfully and function as intended in real-world scenarios.

## Objectives
* **Generate & Deploy:** Automate the provisioning of full-stack environments. The forge supports dual-path IaC generation: traditional provisioning via Terraform and Helm, and Kubernetes-native declarative infrastructure via Config Connector.
* **Test & Validate:** Provide a robust sandbox execution environment that continuously tests reference architectures to confirm they work out-of-the-box.
* **Consolidate:** Act as a central forge to pull together disparate Google Cloud patterns into cohesive, validated, and security-scanned stacks.

## Supported Public Reference Templates
As a starting point, this project looks to the following publicly available repositories. The forge enables the building out of these reference architectures and continuously validates their reliability:

* **[Cloud Foundation Toolkit](https://github.com/GoogleCloudPlatform/cloud-foundation-toolkit)**
* **[Cluster Toolkit](https://github.com/GoogleCloudPlatform/cluster-toolkit)**
* **[Kubernetes Engine Samples](https://github.com/GoogleCloudPlatform/kubernetes-engine-samples)**
* **[Terraform GKE Modules](https://github.com/terraform-google-modules/terraform-google-kubernetes-engine)**
* **[Terraform Docs Samples (GKE)](https://github.com/terraform-google-modules/terraform-docs-samples/tree/main/gke)**
* **[GKE AI Labs](https://gke-ai-labs.dev/)**
* **[GKE AI Labs (Early Adopter Code Samples)](https://github.com/ai-on-gke/tutorials-and-examples)**
* **[LLM-D](https://github.com/llm-d/llm-d)**
* **[Accelerated Platforms](https://github.com/GoogleCloudPlatform/accelerated-platforms)**
* **[Generative AI](https://github.com/GoogleCloudPlatform/generative-ai)**
* **[GKE Policy Automation](https://github.com/google/gke-policy-automation)**
* **[Gemini for Kubernetes Development](https://github.com/gke-labs/gemini-for-kubernetes-development)**

## Architecture & Validation Pipeline
* **Control Plane:** A GKE Standard cluster hosting the orchestration and validation agents.
* **Infrastructure as Code (Dual-Path):**
  * **Terraform/Helm:** Traditional IaC for base infrastructure provisioning combined with Helm for workload deployment.
  * **Config Connector:** Cloud-native infrastructure management using Kubernetes Custom Resource Definitions (CRDs) to deploy and manage Google Cloud resources directly from the cluster.
* **Validation Sandbox:** Automated testing execution and security scanning within an isolated Google Cloud project to guarantee the stability of the generated templates.

## Current Status
* Initial repository scaffolding established.
* Validation agent infrastructure drafted and validated with Terraform.
* Framework ready to ingest, deploy, and validate architectures from the designated upstream public repositories.

## Next Steps
To complete the setup and deploy the infrastructure validation pipeline, please refer to the manual intervention steps detailed in `GUIDANCE.md` regarding identity creation and Secret Manager configuration.

## Repository Structure
* `.github/`: Issue templates and GitHub Actions workflows for continuous validation.
* `agent-infra/`: Terraform code for cluster provisioning and agent manifests.
* `templates/`: Destination for the integrated, tested, and successfully validated full-stack templates.
  * `[template-name]/`
    * `terraform-helm/`: IaC implementation using Terraform and Helm.
    * `config-connector/`: Native Kubernetes IaC implementation using Google Cloud Config Connector.
