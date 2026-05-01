# Verification Plan - Multi-Tenant Ray with Kueue

This plan outlines the steps to verify the multi-tenant Ray on GKE with equitable queuing.

## Infrastructure Verification

1.  **GKE Cluster:** Verify the cluster is created with Gateway API enabled.
2.  **Node Pools:**
    *   `system-pool`: Check for e2-standard-4 nodes.
    *   `gpu-pool`: Check for g2-standard-4 nodes with L4 GPUs and autoscaling enabled.
3.  **Cloud NAT:** Verify the Cloud NAT and Router are configured for the VPC.

## Workload Verification

1.  **Operators:**
    *   Verify KubeRay operator is running.
    *   Verify Kueue operator is running in `kueue-system` namespace.
2.  **Kueue Configuration:**
    *   Verify `ResourceFlavor` `default-flavor` exists with `gpu: l4` label.
    *   Verify `ClusterQueues` `team-a-cq` and `team-b-cq` are created and in the same cohort.
    *   Verify `LocalQueues` `ray-queue` exist in both `team-a` and `team-b` namespaces.
3.  **Multi-Tenancy:**
    *   Check namespaces `team-a` and `team-b`.
    *   Verify `RayCluster` resources exist in both namespaces.
    *   Check that Ray head and worker pods are eventually scheduled.

## Queuing Logic Verification (Manual)

To verify equitable queuing:
1.  Scale `team-a` worker replicas to 5.
    *   Since `team-a-cq` has `nominalQuota: 2` and `borrowingLimit: 0`, Kueue should only allow 2 workers to start.
    *   Remaining pods should stay in `Pending` state (or `Suspended` by KubeRay/Kueue).
2.  Scale `team-b` worker replicas to 4.
    *   Since `team-b-cq` has `nominalQuota: 2` and `borrowingLimit: 2`, it should be able to use 4 GPUs if `team-a` is not using them.
    *   If both teams want 4 GPUs, `team-a` gets 2, `team-b` gets 2 (total 4).
