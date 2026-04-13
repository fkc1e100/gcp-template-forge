# Experiments Log - basic-gke-hello-world

| Attempt | Change | CI Result | Hypothesis | Next step |
|---|---|---|---|---|
| 1 | Initial setup | ❌ Timeout | GKE Standard might be more reliable than Autopilot | Convert to Standard |
| 2 | Convert to Standard, rename KCC to -v2 | ❌ CI Fail | Install gke-gcloud-auth-plugin failed | Fix workflow repo |
| 3 | Fix workflow repo | Pending | Repo fix resolves CI | Verify CI |
