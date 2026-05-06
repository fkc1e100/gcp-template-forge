# Test KCC Skip
This template is used to verify the KCC skip mechanism.

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## KCC Status: Unsupported
This template uses features that are not yet available in Config Connector. 
KCC CI jobs are skipped for this template.

For more information, see:
- [Issue #6861](https://github.com/GoogleCloudPlatform/k8s-config-connector/issues/6861)
- [PR #6899](https://github.com/GoogleCloudPlatform/k8s-config-connector/pull/6899)

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `test-kcc-skip` |
| `service_account` | Node pool service account | required |

