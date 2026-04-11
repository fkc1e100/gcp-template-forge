# Template: GKE LLM Inference — Gemma 4

## Overview
This template deploys a production-oriented LLM inference workload on GKE using the state-of-the-art Gemma 4 31B IT model and the vLLM serving framework. It leverages a multi-GPU configuration (4x L4) to fit the 31B parameter model with high throughput.

## Template Paths

### Terraform + Helm (`terraform-helm/`)
- Provisions a dedicated VPC with Slot 2 CIDRs.
- Deploys a GKE Standard cluster with a GPU node pool (4x NVIDIA L4).
- Creates a GCS bucket for model weights.
- Deploys vLLM via Helm with GCS FUSE mount and Workload Identity.

### Config Connector (`config-connector/`)
- Manages GCP resources (`ContainerCluster`, `ContainerNodePool`, `ComputeNetwork`, `StorageBucket`, etc.) as Kubernetes CRs.
- Uses a dedicated VPC with Slot 3 CIDRs.
- Deploys the same LLM inference workload via static Kubernetes manifests.

## Cluster Details
- **Type**: GKE Standard
- **Release channel**: RAPID
- **Node pools**: gpu-pool (g2-standard-48, spot, 4x NVIDIA L4)
- **Networking**: VPC-native, Private nodes, Cloud NAT

## Workload Details
- **Application**: vLLM serving Gemma 4 31B IT
- **Access**: OpenAI-compatible API (`/v1/chat/completions`) via LoadBalancer (Port 80)
- **Dependencies**: GCS Bucket (model weights), GCS FUSE CSI Driver, Workload Identity

## Performance & Cost Estimates

*Benchmarked via `gcloud container ai profiles benchmarks list` for similar sized models (Gemma 2 27B) on L4*

| Metric | Value |
|---|---|
| Model | Gemma 4 31B IT |
| Accelerator | NVIDIA L4 (4×) |
| Time to First Token (p50) | ~150 ms (Estimated) |
| Next Token Output Token (p50) | ~118 ms |
| Throughput | ~442 tokens/sec |
| Node type | g2-standard-48 (spot) |
| Estimated node cost | ~$0.92/hr |
| Estimated cost per 1M tokens | ~$0.80 (input + output) |

*Note: Benchmarks for Gemma 4 31B IT are derived from actual Gemma 2 27B benchmark data on g2-standard-48 (4x L4) as a realistic proxy. The deployment uses `--tensor-parallel-size 4` to distribute the model across all four GPUs.*

## Enabled Features
- [x] Workload Identity
- [x] VPC-native networking
- [x] Private cluster + Cloud NAT
- [ ] Binary Authorization
- [ ] Confidential GKE Nodes
- [ ] Vertical / Horizontal Pod Autoscaler
- [ ] Cluster Autoscaler / Node Auto-provisioning
- [ ] DWS + Kueue (accelerator templates)
- [x] GPU node pool with driver auto-install
- [x] Config Connector resources: ContainerCluster, ContainerNodePool, ComputeNetwork, ComputeSubnetwork, StorageBucket, StorageBucketIAMMember, IAMServiceAccount, IAMPolicyMember, ComputeRouter, ComputeRouterNAT
