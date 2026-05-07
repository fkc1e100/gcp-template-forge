# Test KCC Skip
This template is used to verify the KCC skip mechanism.

## Architecture
- **No-op Infrastructure** — This template does not provision any real resources. It is used to test CI filtering logic.

## KCC Status: Unsupported
This template uses features that are not yet available in Config Connector. 
KCC CI jobs are skipped for this template.

For more information, see:
- [Issue #6861](https://github.com/GoogleCloudPlatform/k8s-config-connector/issues/6861)
- [PR #6899](https://github.com/GoogleCloudPlatform/k8s-config-connector/pull/6899)
