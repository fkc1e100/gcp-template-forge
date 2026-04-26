# Verification Plan

1. **Cluster and Node Pool Readiness**: Verify the GKE cluster and the L4 GPU node pool are successfully provisioned.
2. **Operator Readiness**: Verify that the Kueue controller-manager and KubeRay operator deployments are available.
3. **Equitable Queuing**: Check that Kueue intercepts the RayClusters. With 1 GPU available and 2 RayClusters requesting 1 GPU each, exactly one workload should be Admitted while the other remains Pending in the ClusterQueue.
