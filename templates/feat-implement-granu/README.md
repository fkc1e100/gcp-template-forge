# Granular Progress Tracking for Agent Recovery

This template provisions a GKE cluster and deploys a Python workload that simulates agent progress tracking. The application maintains state in a `progress.json` file and exposes it via an HTTP endpoint.

## Deployment Paths

### Config Connector Path
The `config-connector/` directory contains KCC manifests for GKE infrastructure provisioning.
The `config-connector-workload/` directory contains standard Kubernetes manifests for the application.

1. Ensure KCC is installed and WIF is configured.
2. Apply the KCC manifests in the management cluster.
3. Apply the workload manifests in the provisioned cluster.

## Functional Validation
Run `./validate.sh` to ensure the workload endpoints return the correctly tracked progress state from `progress.json`.
