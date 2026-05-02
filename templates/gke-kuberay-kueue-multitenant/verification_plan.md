# Verification Plan: Multi-Tenant Ray on GKE with Equitable Queuing

## Objective
Verify that GKE can host multiple Ray clusters in different namespaces, and that Kueue successfully manages GPU resource distribution, allowing borrowing between teams while enforcing nominal quotas.

## Infrastructure
- GKE Cluster in `us-central1` (regional).
- G2-standard-4 node pool (L4 GPUs).
- Ray Operator Add-on enabled.
- Kueue Operator installed.

## Verification Steps

### 1. Provisioning
- Run `terraform apply`.
- Verify GKE cluster and node pools are `PROVISIONING` then `RUNNING`.
- Verify Ray Operator pod is `Running`.

### 2. Workload Deployment
- Install Kueue via `validate.sh`.
- Deploy the Helm chart.
- Verify `ResourceFlavor`, `ClusterQueues`, and `LocalQueues` are `Ready`.
- Verify `RayCluster` resources are created in `team-a` and `team-b` namespaces.

### 3. Functional Testing (Equitable Sharing)
- **Baseline**: Team A and Team B each have a `RayCluster` with 1 worker pod requesting 1 GPU. Total GPUs = 2.
- **Scenario**:
    - Team A's `RayCluster` is scaled to 2 workers.
    - Since Team B is only using 1 GPU, and the total capacity is 2, Team A should be able to borrow the extra GPU if the total quota allows it, OR it might be queued if we limited the total GPUs.
- **Verification**:
    - Check Kueue `Workload` objects to see if they are `Admitted`.
    - Check Ray head and worker pods are `Running`.

## Expected Results
- Both teams can run their Ray head pods.
- Ray worker pods are admitted by Kueue only when quota is available or borrowing is allowed.
- Equitable sharing is demonstrated by Kueue balancing the requests.

## Cleanup
- Run `terraform destroy`.
- Verify all GCP resources (Cluster, VPC, Forwarding Rules) are removed.
