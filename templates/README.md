# GKE Reference Architecture Templates

This directory serves as the centralized catalog for all unified, validated Google Kubernetes Engine (GKE) reference architecture templates. Each template implements industry best practices for security, reliability, scalability, and cost optimization, providing dual deployment paths: **Terraform + Helm** and **Config Connector (KCC)**.

---

## Validation Status Catalog

To ensure absolute reliability, every reference architecture undergoes automated end-to-end sandbox validation on live Google Cloud Platform (GCP) resources before being marked as verified.

| Template / Directory Name | Terraform + Helm | Config Connector (KCC) | Status Details & Skip Reason |
| :--- | :---: | :---: | :--- |
| 🚀 **[gke-basic-hello-world](./gke-basic-hello-world)** | ⚪ `skipped` | ⚪ `skipped` | **Skipped**: Retained from baseline. Skipped in recent pipeline runs to optimize build time since core files were unmodified. |
| 🛡️ **[gke-custom-compute-class](./gke-custom-compute-class)** | ⚪ `skipped` | ⚪ `skipped` | **Skipped**: Retained from baseline. Skipped in recent pipeline runs to optimize build time since core files were unmodified. |
| 🏢 **[gke-enterprise-cluster](./gke-enterprise-cluster)** | ⚪ `skipped` | ⚪ `skipped` | **Skipped**: Retained from baseline. Skipped in recent pipeline runs to optimize build time since core files were unmodified. |
| 🕸️ **[gke-fqdn-egress-security](./gke-fqdn-egress-security)** | ⚪ `skipped` | ⚪ `skipped` | **Skipped**: Retained from baseline. Skipped in recent pipeline runs to optimize build time since core files were unmodified. |
| 🧠 **[gke-inference-fuse-cache](./gke-inference-fuse-cache)** | ⚪ `skipped` | ⚪ `skipped` | **Skipped**: Retained from baseline. Skipped in recent pipeline runs to optimize build time since core files were unmodified. |
| 🔑 **[gke-k8s-rbac-manager](./gke-k8s-rbac-manager)** | 🟡 `pending` | 🟡 `pending` | **Pending**: Triggers deployed on active feature branch. Awaiting pipeline execution to record initial live success. |
| 📦 **[gke-k8s-service-deployment](./gke-k8s-service-deployment)** | 🟡 `pending` | 🟡 `pending` | **Pending**: Triggers deployed on active feature branch. Awaiting pipeline execution to record initial live success. |
| 📊 **[gke-kuberay-kueue](./gke-kuberay-kueue)** | ⚪ `skipped` | ⚪ `skipped` | **Skipped**: Retained from baseline. Skipped in recent pipeline runs to optimize build time since core files were unmodified. |
| 🌟 **[gke-latest-features](./gke-latest-features)** | ⚪ `skipped` | ⚪ `skipped` | **Skipped**: Retained from baseline. Skipped in recent pipeline runs to optimize build time since core files were unmodified. |
| 🛒 **[gke-online-boutique](./gke-online-boutique)** | 🟢 `success` | 🟡 `pending` | **Partially Verified**: Terraform path is successful. Config Connector trigger is active on feature branch awaiting live validation. |
| 📈 **[gke-spot-autoscale](./gke-spot-autoscale)** | 🟡 `pending` | 🟡 `pending` | **Pending**: Triggers deployed on active feature branch. Awaiting pipeline execution to record initial live success. |
| 🧪 **[gke-test-kcc-skip](./gke-test-kcc-skip)** | ⚪ `skipped` | ⚪ `skipped` | **Skipped**: Config Connector is explicitly unsupported (`.kcc-unsupported` present) as GKE Hub cluster registers are not supported in the local test sandbox. |
| 🗺️ **[gke-topo-routing](./gke-topo-routing)** | ⚪ `skipped` | ⚪ `skipped` | **Skipped**: Retained from baseline. Skipped in recent pipeline runs to optimize build time since core files were unmodified. |

---

## Validation & Change Detection System

The continuous integration pipeline ([ci-post-merge.yml](../.github/workflows/ci-post-merge.yml)) utilizes a smart change detection system to prevent unnecessary resource allocation:

1. **Automatic Detection**: When a pull request is merged, the `detect-changes` action analyzes the differences. Any modification inside a template's directory (e.g. `templates/gke-basic-hello-world/`) flags that template for build validation.
2. **Resource Provisioning**: The pipeline spins up GKE clusters, deploys the workloads, executes `/validate.sh` checks to assert end-to-end readiness, and teardowns the resources gracefully.
3. **Automated Documentation**: On success, the pipeline commits the updated **Validation Record** table and a `.validated` checkpoint file directly back to the `main` branch.

### Manual Trigger Mechanism

If you need to force a redeployment and validation run for a template without modifying its core code, create or touch a `trigger.txt` file inside its directory with the following content:
```text
Trigger CI detection
```
Once pushed and merged, the change detection mechanism will automatically schedule a complete deployment validation run for that template.
