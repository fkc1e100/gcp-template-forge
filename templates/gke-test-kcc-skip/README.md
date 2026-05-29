# GKE Test KCC Skip

This template is designed to test the Config Connector (KCC) unsupported/skip path for Epic #447.

## KCC Unsupported Marker
By placing the `.kcc-unsupported` marker file inside the `config-connector/` directory, this template signals that the KCC path is skipped. The platform should gracefully handle this by falling back to the Terraform path or recording it as skipped.
