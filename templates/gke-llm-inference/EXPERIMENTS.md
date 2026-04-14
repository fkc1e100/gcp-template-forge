# Experiments Log

| Attempt | Change | CI Result | Hypothesis | Next step |
|---|---|---|---|---|
| 1 | Set wait=false on helm upgrade and increased timeouts (1800s) | ❌ Timeout | Pod failed to become ready in 30 min | Increase timeout to 60 min |
| 2 | Increased timeout to 3600s and added diagnostics | ❌ Timeout | Pod failed to become ready in 60 min; diagnostics failed due to Unauthorized | Increase timeout to 90 min, switch to get-credentials for robust auth, and use Recreate strategy |
| 3 | 90m timeout, get-credentials auth, Recreate strategy | | Recreate strategy avoids GPU quota conflicts; get-credentials ensures robust auth for diagnostics | Wait for CI |
| 4 | Add helm_release with wait=false, use GEMINI.md get-credentials pattern, and set startupProbe threshold to 120 | | wait=false avoids TF timeout; robust credentials avoid Unauthorized; probe fits within 60m CI timeout | Wait for CI |
