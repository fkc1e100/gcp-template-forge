# Verification Plan - Multi-Tenant Ray on GKE with Kueue

## Infrastructure Validation (Terraform)
- [ ] VPC and Subnet are created with correct secondary ranges.
- [ ] GKE Cluster is created with Dataplane V2 enabled.
- [ ] `system-pool` has 2 nodes.
- [ ] `gpu-pool` is created with Tesla T4 GPUs and time-sharing enabled.
- [ ] `values.yaml` is generated correctly by Terraform.

## Workload Validation (Helm)
- [ ] `kuberay-operator` deployment is healthy in `kuberay-system`.
- [ ] `kueue-controller-manager` deployment is healthy in `kueue-system`.
- [ ] `team-a` and `team-b` namespaces are created.
- [ ] Kueue `ResourceFlavor`, `ClusterQueue`, and `LocalQueues` are created.
- [ ] `RayCluster` resources are created in both namespaces.

## Functional Validation
- [ ] **Admission Check:** Verify that Kueue admits the Ray head and worker pods.
- [ ] **Quota Enforcement:** (Manual) If possible, increase the number of workers in Team A and verify that they remain `Pending` until resources are available.
- [ ] **GPU Readiness:** Verify that NVIDIA GPU drivers are installed (default on GKE) and GPUs are accessible to Ray workers.

## Automated Test (`validate.sh`)
- [ ] Script successfully authenticates to the cluster.
- [ ] Script waits for both operators to reach `Available` status.
- [ ] Script waits for the `ClusterQueue` to reach `Active` status.
- [ ] Script waits for Ray head and worker pods to reach `Ready` status in both namespaces.
