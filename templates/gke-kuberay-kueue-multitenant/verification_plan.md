# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Verification Plan - Multi-Tenant Ray on GKE with Kueue

This document outlines the plan for verifying the `gke-kuberay-kueue-multitenant` template.

## Test Environment
- **Project**: `<PROJECT_ID>`
- **Region**: `us-central1`
- **Tools**: `terraform`, `helm`, `kubectl`, `gcloud`

## 1. Infrastructure Verification (Terraform)
- [ ] Run `terraform plan` to ensure VPC, Subnet, Cluster, and Node Pools are correctly defined.
- [ ] Verify that explicit `timeouts` (45m) are set on all node pools.
- [ ] Verify that the GPU node pool has the correct taints (`nvidia.com/gpu: NoSchedule`) and labels.
- [ ] Verify that GKE managed driver installation is enabled.
- [ ] Run `terraform apply` and wait for cluster readiness.

## 2. Workload Verification (Helm / Kubernetes)
- [ ] Verify that `team-a` and `team-b` namespaces are created.
- [ ] Verify that KubeRay and Kueue operators are running with 2 replicas for High Availability.
- [ ] Verify that Kueue `ResourceFlavor`, `ClusterQueues`, and `LocalQueues` are correctly configured with cohorts.
- [ ] Verify that `RayCluster` resources in each namespace are admitted by Kueue.

## 3. Behavioral Verification (Equitable Queuing)
### Scenario 1: Nominal Usage
- [ ] Team A and Team B each have 1 `RayCluster` requesting 1 GPU.
- [ ] Total GPUs used = 2 (within total quota of 4).
- [ ] **Expected**: Both clusters reach `ready` state.

### Scenario 2: Borrowing
- [ ] Scale Team A's cluster to 4 replicas (4 GPUs).
- [ ] Team B has 0 GPUs used.
- [ ] **Expected**: Team A borrows 2 GPUs from the cohort and runs 4 replicas.

### Scenario 3: Preemption / Equitable Sharing
- [ ] While Team A is using 4 GPUs, start a Ray job in Team B requesting 2 GPUs.
- [ ] **Expected**: Kueue identifies that Team B is entitled to its nominal quota of 2. It should either preempt Team A's borrowing pods or hold Team B's job until resources are reclaimed, ensuring Team B gets its fair share.

## 4. Cleanup
- [ ] Run `terraform destroy` (or delete KCC resources).
- [ ] Verify all GCP resources (VPC, GKE, Disks) are removed.
