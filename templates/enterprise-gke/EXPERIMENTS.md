# Experiments Log - enterprise-gke

| Attempt | Change | CI Result | Hypothesis | Next step |
|---|---|---|---|---|
| 1-18 | Various fixes for ports, KCC, and TF | ❌ Mixed | Port mismatch and immutable fields | Rename KCC resources and sync ports |
| 19 | Rename KCC to -v3, node pool to -v3 | ❌ CI Fail | Install gke-gcloud-auth-plugin failed | Fix workflow repo |
| 20-30 | Identity and Security Alignment | ✅ Success | Master Authorized Networks, Node SAs, and Workload Identity alignment | Finalize template |
| 31 | Fix SA creation permissions | ✅ Success | Toggle for SA creation allows CI to pass in restricted env | Final polish |
| 32 | Final consistency and docs polish | ✅ Success | Align KCC details in README and update latest commit hash | Production ready |

## Key Learnings
- **Master Authorized Networks**: Restricting control plane access improves security but requires careful coordination with CI/CD tools.
- **Service Account Robustness**: Using `substr` and `replace` to ensure SA `account_id` is within 30 chars and sanitized is critical for dynamic naming.
- **Functional Parity**: Ensuring identical CIDRs, security configs, and identity models between TF and KCC paths is essential for template consistency.
- **CI Compatibility**: A toggle like `create_service_accounts` is a good pattern to support both restricted CI environments and production-ready deployments.
