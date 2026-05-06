
I have updated the `templates/gke-fqdn
-egress-security/README.md` to strictly follow the project's standard scaffold as defined in `agent-infra
/scaffolds/README.template.md`.

The updated README now includes:
- Correct header structure and placeholders (`<!-- CI:
 validation record ... -->`).
- Detailed architecture description for the GKE FQDN egress security template.
- Accurate
 resource naming and estimated cost sections.
- Comprehensive deployment instructions for both Terraform + Helm and Config Connector (KCC) paths.
-
 Proper verification steps using the `validate.sh` script.

I have committed the changes to the `fix/issue-241
` branch and pushed them to the repository. The existing PR #249 (which closes #241) has
 been updated and already has auto-merge enabled.

