# Verification Plan

1. Verify that the GKE cluster was created with both the `system-pool` and the `l4-gpu-pool`.
2. Ensure the KubeRay Operator and Kueue Operator are running.
3. Check `kubectl get clusterqueues` to ensure `team-a-cq` and `team-b-cq` are active and share the same cohort.
4. Verify `kubectl get localqueues -A` lists queues for both `team-a` and `team-b`.
5. Check `kubectl get rayclusters -A` and verify that Kueue has suspended the jobs beyond the nominal quota or admitted them based on sharing.