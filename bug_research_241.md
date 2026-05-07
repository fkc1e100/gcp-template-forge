# Bug Research Report: Issue #241
## [CI-BUG] gke-fqdn-egress-security README does not follow standard template

### 1. Root Cause Analysis
The `README.md` in `templates/gke-fqdn-egress-security/` fails to comply with the standard project template defined in `agent-infra/scaffolds/README.template.md`. This discrepancy likely stems from the template being created using an older or inconsistent format. While it contains the necessary deployment paths, several structural and semantic elements deviate from the established standards for the `gcp-template-forge` project.

Additionally, a significant inconsistency exists between the resource naming in the `README.md`, the actual Terraform/KCC implementation, and the `shortName` defined in `template.yaml`.

### 2. Discrepancies and Issues Identified

#### README Structural Deviations
- **Template Inputs Table:**
    - The default values for `cluster_name`, `network_name`, and `subnet_name` use an outdated pattern (`...-cluster`, `...-vpc`, `...-subnet`) instead of the standard `{{SHORT_NAME}}-tf` pattern (e.g., `gke-fqdn-egress-tf`).
    - The `service_account` variable is present in `variables.tf` but missing from the README's inputs table.
- **KCC Section Bug:**
    - The `kubectl get containerclusters` command in Path 2 uses a label filter `-l "template=gke-fqdn-egress"`. However, the actual `config-connector/cluster.yaml` uses `template: gke-fqdn-egress-security`. This mismatch would cause the command to fail in a real deployment scenario.
- **KCC Limitations Section:**
    - The mandatory placeholder `{{KCC_LIMITATIONS_SECTION}}` (or a corresponding section if none apply) is missing entirely.
- **Architecture Section:**
    - The structure is slightly non-standard, including an extra "The architecture includes:" list not found in the scaffold.

#### Project Standard Violations (Naming)
- The project mandates using the `shortName` for resource naming to avoid exceeding GCP resource naming limits and to maintain consistency.
- `shortName` for this template is `gke-fqdn-egress`.
- Current implementation uses `gke-fqdn-egress-security-...` for nearly all resources in both TF and KCC paths, which is inconsistent with other templates like `basic-gke-hello-world`.

### 3. Proposed Plan of Action

To bring the template into full compliance, the following changes are required across multiple files:

#### A. Update README.md (`templates/gke-fqdn-egress-security/README.md`)
1.  Align the **Template Inputs** table with standard defaults:
    - `cluster_name`: `gke-fqdn-egress-tf`
    - `network_name`: `gke-fqdn-egress-tf-vpc`
    - `subnet_name`: `gke-fqdn-egress-tf-subnet`
2.  Add `service_account` to the **Template Inputs** table.
3.  Add the `{{KCC_LIMITATIONS_SECTION}}` placeholder or a commented-out section.
4.  Update the **KCC credential command** to use the correct label (which will be updated in `cluster.yaml`).
5.  Ensure the **Resource Naming** table accurately reflects the updated implementation.

#### B. Update Terraform Variables (`templates/gke-fqdn-egress-security/terraform-helm/variables.tf`)
1.  Update `variable "cluster_name"` default to `gke-fqdn-egress-tf`.
2.  Update `variable "network_name"` default to `gke-fqdn-egress-tf-vpc`.
3.  Update `variable "subnet_name"` default to `gke-fqdn-egress-tf-subnet`.

#### C. Update Config Connector Manifests (`templates/gke-fqdn-egress-security/config-connector/`)
1.  **`cluster.yaml`**: Update name to `gke-fqdn-egress-kcc`, update network/subnet references, and fix the `template` label to `gke-fqdn-egress`.
2.  **`network.yaml`**: Update VPC, Subnet, Router, NAT, and Firewall names to use the `gke-fqdn-egress-` prefix. Fix `template` labels.
3.  **`membership.yaml`**: Update membership name and cluster reference. Fix `template` label.
4.  **`nodepool.yaml`**: Update pool name and cluster reference. Update `targetTags` to match updated firewall tags. Fix `template` labels.

#### D. Update Validation Script (`templates/gke-fqdn-egress-security/validate.sh`)
1.  Update the default `CLUSTER_NAME` to `gke-fqdn-egress-tf` (to match the TF default).

### 4. Verification Plan
- Run `agent-infra/local-lint.sh templates/gke-fqdn-egress-security` to ensure structural integrity.
- Manually verify that the README examples match the updated defaults in `variables.tf` and `cluster.yaml`.
- Ensure all `template` labels in KCC manifests are exactly `gke-fqdn-egress`.
