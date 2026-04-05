# Test Workload

This is a test workload designed to verify the automated sandbox provisioning and IaC application.

## Architecture

* **Terraform:** Provisions a GCS bucket with a random suffix.
* **KCC:** Provisions a `StorageBucket` via Config Connector.

## Prerequisites

* Config Connector configured in the cluster.
* Appropriate IAM permissions for the GKE Service Account.
