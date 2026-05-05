# Bug Research Report: Issue #238

## Issue Overview
**Title:** [CI-BUG] basic-gke-hello-world README does not follow standard template
**Description:** The `README.md` in `templates/basic-gke-hello-world/` is inconsistent with the standard defined in `agent-infra/scaffolds/README.template.md`.

## Root Cause Analysis
The `templates/basic-gke-hello-world/README.md` file was likely created before the current standard template was finalized, or it was manually modified without referencing the standard scaffold. As `basic-gke-hello-world` is designated as the "Complete working example" (per `GEMINI.md`), its deviations from the standard cause confusion and trigger CI/consistency bugs.

## Discrepancies Identified

| Feature | `README.template.md` (Standard) | `basic-gke-hello-world/README.md` (Current) |
|---|---|---|
| **CI Marker Location** | Directly below the 1-line description. | At the very bottom of the file. |
| **Header Ordering** | Description -> CI Marker -> Architecture -> Resource Naming -> Cost -> Deployment -> Verification -> Inputs | Description -> Architecture -> Resource Naming -> Cost -> Deployment -> Verification -> Inputs -> CI Marker -> Validation Record |
| **Resource Naming** | Config Connector uses `{{SHORT_NAME}}-<uid>-kcc` | Config Connector uses `basic-gke-hello-world-<uid>` (instead of `gke-basic-<uid>-kcc`) |
| **KCC Limitations** | Placeholder `{{KCC_LIMITATIONS_SECTION}}` present | Missing entirely |

*Note: The existing issue report claims the CI Marker and Template Inputs are missing; however, they are present but located at the bottom of the file.*

## Proposed Action Plan

To fix this issue without overstepping the scope (modifying only the README to match the template), perform the following changes in `templates/basic-gke-hello-world/README.md`:

1.  **Relocate the CI Marker:**
    Move the `<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->` comment from the bottom of the file to directly below the one-line description quotation.
    
2.  **Reorder Sections:**
    Ensure the headers follow the exact sequence defined in the scaffold:
    - `# Basic GKE Hello World`
    - `> A minimal GKE Standard cluster...`
    - `<!-- CI: validation record... -->`
    - `## Architecture`
    - `### Resource Naming`
    - `### Estimated Cost`
    - `## Deployment Paths`
    - `### Path 1: Terraform + Helm`
    - `### Path 2: Config Connector (KCC)`
    - *(Add KCC Limitations section here)*
    - `## Verification`
    - `## Template Inputs`

3.  **Update Resource Naming Table:**
    Update the "Config Connector" column in the Resource Naming table to match the standard `{{SHORT_NAME}}-<uid>-kcc` format using the template's short name (`gke-basic`).
    | Resource | Terraform + Helm | Config Connector |
    |---|---|---|
    | GKE Cluster | `gke-basic-<uid>-tf` | `gke-basic-<uid>-kcc` |
    | VPC Network | `gke-basic-<uid>-tf-vpc` | `gke-basic-<uid>-kcc-vpc` |
    | Subnet | `gke-basic-<uid>-tf-subnet` | `gke-basic-<uid>-kcc-subnet` |

4.  **Add KCC Limitations Placeholder:**
    Insert the standard KCC Limitations placeholder (or a statement saying there are no known limitations) below the Config Connector deployment path.

5.  **Remove Existing Validation Record Table:**
    Delete the existing `## Validation Record` section and its table at the bottom of the file, as the CI pipeline is responsible for generating and appending it.

*Note on Implementation:* The actual KCC manifests currently use `basic-gke-hello-world` instead of `gke-basic`. The agent executing this fix should consider whether to also update the manifests to strictly enforce the standard naming convention, but the primary objective is to fix the README layout.
