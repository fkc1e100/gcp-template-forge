# Experiments Log

| Attempt | Change | CI Result | Hypothesis | Next step |
|---|---|---|---|---|
| 1 | Set wait=false on helm upgrade and increased timeouts (1800s) | ❌ Timeout | Pod failed to become ready in 30 min | Increase timeout to 60 min |
| 2 | Increased timeout to 3600s and added diagnostics | ❌ Timeout | Pod failed to become ready in 60 min; diagnostics failed due to Unauthorized | Increase timeout to 90 min, switch to get-credentials for robust auth, and use Recreate strategy |
| 3 | 90m timeout, get-credentials auth, Recreate strategy | | Recreate strategy avoids GPU quota conflicts; get-credentials ensures robust auth for diagnostics | Wait for CI |
| 4 | Add helm_release with wait=false, use GEMINI.md get-credentials pattern, and set startupProbe threshold to 120 | | wait=false avoids TF timeout; robust credentials avoid Unauthorized; probe fits within 60m CI timeout | Wait for CI |
| 5 | Combine get-credentials and helm upgrade in a single null_resource with triggers | ✅ TF Path | Ensures credentials are set in fresh CI runners even if resource exists in state; triggers ensure re-deployment on value changes. | Done |
| 6 | Add queuedProvisioning to KCC GPU node pool and align startupProbe threshold | ❌ KCC Path | KCC version v1beta1 does not support spec.queuedProvisioning. | Remove it. |
| 7 | Disable create_workload_sa, remove KCC queuedProvisioning, and strictly follow TF/Helm separation. | | CI service account lacks iam.serviceAccounts.create permission; KCC v1beta1 lacks queuedProvisioning; local-exec in main.tf is prohibited. | Wait for CI |
| 8 | Add Cloud NAT, enable TF queued_provisioning, fix local-exec auth plugin issue. | ❌ TF Path | gke-gcloud-auth-plugin missing in Terraform environment. | Use vllm image and gcsfuse for robust staging. |
| 9 | Use vllm image and gcsfuse for robust model staging in Job. | | Eliminates apt/pip/gcloud dependencies in staging job. | Wait for CI |

