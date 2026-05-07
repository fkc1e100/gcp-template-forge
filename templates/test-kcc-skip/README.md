# Test KCC Skip
This template is used to verify the KCC skip mechanism.


## Architecture
This is a minimal test template designed to verify that the CI pipeline correctly identifies and skips the Config Connector path when a `.kcc-unsupported` file is present.

## KCC Status: Unsupported
This template uses features that are not yet available in Config Connector. 
KCC CI jobs are skipped for this template.

For more information, see:
- [Issue #6861](https://github.com/GoogleCloudPlatform/k8s-config-connector/issues/6861)
- [PR #6899](https://github.com/GoogleCloudPlatform/k8s-config-connector/pull/6899)

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->
