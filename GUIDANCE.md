# **Project Specification: GKE Template Forge & Validation Engine**

**Target Executor:** Jetski

**Project Goal:** Build an automated pipeline that takes a user's natural language intent for a Kubernetes architecture via a GitHub Issue, uses repo-agent and overseer to generate the corresponding Infrastructure as Code (Terraform, Helm, Config Connector), and validates the design by deploying it to a GCP sandbox project and performing security scanning before publishing it as a reusable template.

## **1\. Repository Configuration**

**Suggested Repository Names (Account: fkc1e100):**

*(Note: While the initial focus is GKE, these names reflect the broader GCP scope of the long-term project.)*

1. fkc1e100/gcp-template-forge (Recommended: Implies creation, hardening, and building across GCP)  
2. fkc1e100/gcp-blueprint-validator  
3. fkc1e100/gcp-intent-to-iac

**Repository Visibility:** Public

**Core Directories to Bootstrap:**

* .github/ISSUE\_TEMPLATE/: Contains the YAML issue forms for user intent submission.  
* .github/workflows/: CI/CD pipelines for sandbox environment triggering.  
* agent-infra/: Terraform code to deploy the standalone repo-agent and overseer infrastructure.  
* templates/: The final destination for successfully validated Terraform, Helm, and KCC configurations.

## **2\. Standalone Agent Infrastructure Architecture**

Jetski needs to build a dedicated environment to host the AI agents securely.

**Components to Deploy:**

* **Hosting:** GKE Autopilot cluster (e.g., agent-control-plane) to host the repo-agent and overseer containers from gke-labs/gemini-for-kubernetes-development.  
* **Event Listener:** A GitHub App webhook receiver deployed to listen for issues.opened and issue\_comment.created events.  
* **Identity & Access Management (IAM) & Secrets:**  
  * Create a Google Cloud Service Account (GSA): gke-template-builder@gke-gca-2025.iam.gserviceaccount.com.  
  * Bind roles to the GSA in the target project (gke-gca-2025):  
    * roles/container.admin (to create/delete test clusters)  
    * roles/compute.networkAdmin (for VPCs/Subnets)  
    * roles/gkehub.admin (if using Fleet features)  
    * roles/resourcemanager.projectIamAdmin (for Config Connector identity bindings)  
    * roles/secretmanager.secretAccessor (to access the Gemini API Key and GitHub Webhook secrets)  
* **State Backend:** A GCS Bucket (e.g., gs://gke-gca-2025-forge-tf-state) for Terraform state management during validation tests.

## **3\. Workflow Pipeline (The "Overseer" Loop)**

Jetski must configure the agents to follow this exact lifecycle:

1. **Intent Capture:** A user opens a GitHub Issue using the "New GKE Architecture Request" template. The issue contains natural language (e.g., "I need a private GKE cluster that can run a high-traffic web app connecting to Cloud SQL").  
2. **Generation (Repo-Agent):** The GitHub App webhook triggers the repo-agent. The agent calls the Gemini API to translate the intent into:  
   * Terraform files (VPC, GKE Cluster, Node Pools).  
   * Kubernetes Config Connector (KCC) manifests (e.g., SQLInstance, IAMPolicyMember).  
   * Helm values/charts (for the workload).  
3. **Sandbox Execution (Overseer):**  
   * The overseer provisions a dynamic ephemeral workspace.  
   * It executes terraform init, plan, and apply against the gke-gca-2025 project.  
   * It applies the KCC and Helm manifests to the newly created test cluster.  
4. **Validation:**  
   * The overseer runs a verification script to check if Pods are Running and external IPs are reachable.  
   * *For KCC-specific validations, it executes the tests outlined in Section 3.1.*  
5. **Tear Down & Publish:**  
   * Once validated, overseer runs terraform destroy to clean up gke-gca-2025 to save costs.  
   * The repo-agent commits the validated IaC into the templates/{issue-number}-{short-name}/ directory of the fkc1e100 repo and closes the issue with a success comment linking to the code.

### **3.1 KCC Validation Testing Strategy**

To ensure the overseer agent properly validates that Config Connector has successfully deployed and maintains control over GCP resources, it must script and execute the following multi-layered tests during the Validation phase:

* **Resource Readiness Test (Control Plane Validation):** Use kubectl wait to check the status.conditions of all applied KCC custom resources.  
  * *Example:* kubectl wait \--for=condition=Ready sqlinstance/my-database \-n default \--timeout=10m  
  * *Purpose:* Proves the resource is fully provisioned and KCC successfully authenticated with GCP without quota errors.  
* **The "Drift and Revert" Test (Active Control Validation):** Introduce an out-of-band change using the gcloud CLI (e.g., adding a rogue label to a Pub/Sub topic), wait 1-2 minutes, and assert via gcloud that KCC successfully reverted the resource back to the state declared in the Git manifest.  
  * *Purpose:* Proves the KCC controller is healthy, actively reconciling, and enforcing the declared intent.  
* **Workload Identity Integration Test (Data Plane Validation):** Deploy a lightweight Kubernetes Job configured to use the workload's Service Account. The Job should attempt a basic interaction with the KCC-created resource (e.g., executing a psql query via Cloud SQL Auth Proxy, or publishing a Pub/Sub message).  
  * *Purpose:* Proves the end-to-end chain is working, ensuring IAM permissions assigned by KCC are actively propagating to the Pods.  
* **Teardown & Deletion Verification (Lifecycle Validation):** Have Overseer delete the KCC manifests (kubectl delete \-f kcc-manifests/). Then, run a gcloud command to verify the resource is actually gone from GCP.  
  * *Purpose:* Ensures the templates do not accidentally include cnrm.cloud.google.com/deletion-policy: "abandon" annotations, which would leave orphaned resources in the sandbox project.

## **4\. Example Templates (Seed Data for Jetski)**

Jetski should prime the repository with a couple of example intent issues to test the pipeline.

### **Example 1: AI Inferencing using GKE Inference Quickstart (GIQ)**

* **Intent Summary:** "Deploy a GKE cluster optimized for serving Large Language Models using the GKE Inference Quickstart (GIQ). It should have a GPU node pool (L4 or A100) and deploy an example vLLM workload."  
* **Expected IaC Output:**  
  * **Terraform:** GKE Standard/Autopilot cluster with google\_container\_node\_pool configured with accelerator\_type \= "nvidia-l4", time-sharing enabled, and necessary taint/tolerations.  
  * **Helm/Manifests:** Deployment of the GIQ serving stack (e.g., vLLM or Triton) with the appropriate model weights injected via a persistent volume or GCS fuse, and an exposed Service.

### **Example 2: Config-Connector Powered Microservices**

* **Intent Summary:** "Create an internal microservice architecture that requires a highly available Cloud SQL PostgreSQL database, a Pub/Sub topic for events, and a secure GKE cluster (supporting both Autopilot and Standard configurations) to run the workloads."  
* **Expected IaC Output:**  
  * **full-stack/ (Terraform & Helm):**  
    * **Terraform:** VPC, Subnets, Private Service Access, and a GKE cluster (with parameterized toggles for either Autopilot or Standard mode). Workload Identity configured.  
    * **Helm:** A sample application deployment configured to use Kubernetes Service Accounts (KSA) bound to Google Service Accounts (GSA) to securely access the DB and Pub/Sub without stored secrets.  
  * **kcc-manifests/ (Config Connector):**  
    * **Config Connector (KCC):** YAML manifests for infrastructure like ComputeNetwork (VPC) and ComputeSubnetwork, as well as services like SQLInstance (Postgres), SQLDatabase, SQLUser, PubSubTopic, and PubSubSubscription.

## **5\. Jetski Execution Protocols & Development Guidelines**

To ensure smooth, continuous development and to prevent the agent from getting stuck in loops, Jetski must adhere to the following operational protocols:

### **5.1. Iterative Development Phases**

Jetski should not attempt to build the entire system in a single pass. Execute in this order:

1. **Phase 1 (Repository & Scaffolding):** Create the GitHub repository, directory structure, and basic GitHub Actions CI/CD workflows.  
2. **Phase 2 (Agent Infrastructure):** Write and test the Terraform in agent-infra/.  
   * *Manual Intervention Required:* Before the Terraform can fully deploy a working agent, a human must manually create a GitHub App in the organization/account, configure the required OAuth permissions/webhooks, and securely store the resulting App ID, Private Key, Webhook Secret, and Gemini API Key in Google Cloud Secret Manager.  
   * Do not proceed until these manual steps are complete and the repo-agent and overseer containers are successfully running in GCP and authenticated.  
3. **Phase 3 (Webhook Integration):** Connect the GitHub App webhooks to the running agent infrastructure and verify payload reception.  
4. **Phase 4 (End-to-End Testing):** Submit the Example 1 (GIQ) intent issue to test the full generation \-\> sandbox \-\> teardown \-\> publish loop.

### **5.2. Blocker Management & Escalation**

If Jetski encounters an error, it must follow these resolution paths rather than blindly retrying:

* **IAM / Permission Denied Errors:**  
  * *Action:* Halt the current apply cycle.  
  * *Escalation:* Identify the exact GCP API and permission missing. Create a GitHub Issue titled \[BLOCKED\] Missing IAM Role detailing the required role and the target Service Account. Stop development on this branch until a human resolves it.  
* **Terraform State Locks or Conflicts:**  
  * *Action:* Do **not** use \-force-unlock automatically.  
  * *Escalation:* Check if another workflow is currently running. If the lock persists for \>15 minutes without an active job, log a warning and alert the repository owner via an issue comment.  
* **API Quota / Rate Limiting (GCP or GitHub):**  
  * *Action:* Implement exponential backoff. If GCP hardware limits are hit (e.g., "GPU quota exceeded"), fall back to a standard node pool to test pipeline logic, noting the hardware fallback in the final PR/Issue.  
* **KCC Resource Incompatibility:**  
  * *Action:* If Config Connector fails to apply a generated resource, attempt *one* automatic syntax correction. If it fails again, fall back to generating native Terraform for that specific component and log the KCC failure.

### **5.3. Code Quality & Standards**

* **Formatting:** All Terraform code must pass terraform fmt and terraform validate before being committed.  
* **Idempotency:** All generated code must be idempotent. Re-running the pipeline on the same intent should yield zero changes.  
* **Documentation:** Every generated templates/ folder must include an auto-generated README.md explaining the architecture, prerequisites, and deployment instructions.

### **5.4. Git Workflow Strategy**

* **Branching:** Do not commit directly to main during development. Always create a new branch feature/agent-infra or feature/github-actions.  
* **Publishing Templates:** When the pipeline successfully validates an architecture, the agent should commit the code to a new branch (e.g., template/issue-\#) and open a Pull Request against main for human review, rather than force-pushing directly.

### **5.5. Security & Secret Management (CRITICAL)**

* **Zero Hardcoded Secrets:** Jetski must NEVER hardcode API keys, database passwords, private keys, or GitHub tokens in Terraform, Helm values, or Config Connector manifests.  
* **Secret Injection:** All required credentials for the pipeline must be referenced via GCP Secret Manager data sources in Terraform or injected securely via Workload Identity in GKE.

## **6\. Next Steps for Jetski**

1. Authenticate with GitHub as the fkc1e100 user/organization.  
2. Initialize the gcp-template-forge repository.  
3. Begin **Phase 1** and **Phase 2** as outlined in the Execution Protocols (Section 5.1).