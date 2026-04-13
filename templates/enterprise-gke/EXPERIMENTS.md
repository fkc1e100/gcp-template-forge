# Experiments Log - enterprise-gke

| Attempt | Change | CI Result | Hypothesis | Next step |
|---|---|---|---|---|
| 1-18 | Various fixes for ports, KCC, and TF | ❌ Mixed | Port mismatch and immutable fields | Rename KCC resources and sync ports |
| 19 | Rename KCC to -v3, node pool to -v3 | ❌ CI Fail | Install gke-gcloud-auth-plugin failed | Fix workflow repo |
| 20 | Fix workflow repo, allow all ingress in NP | Pending | Repo fix resolves CI; NP fix resolves endpoint | Verify CI |
