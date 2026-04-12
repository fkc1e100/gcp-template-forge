# Template: GKE LLM Inference — Gemma 2 9B IT

## Overview
This template deploys a production-oriented LLM inference workload on GKE using the Gemma 2 9B IT model and the vLLM serving framework. It leverages a multi-GPU configuration (4x L4) for high throughput and low latency.

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
- **Node pools**: gpu-pool (g2-standard-12, spot, 1x NVIDIA L4)
- **Networking**: VPC-native, Private nodes, Cloud NAT

## Workload Details
- **Application**: vLLM serving Gemma 2 9B IT
- **Access**: OpenAI-compatible API (`/v1/chat/completions`) via LoadBalancer (Port 80)
- **Dependencies**: GCS Bucket (model weights), GCS FUSE CSI Driver, Workload Identity

## Performance & Cost Estimates

*Benchmarked via `gcloud container ai profiles benchmarks list` for Gemma 2 9B on L4*

| Metric | Value |
|---|---|
| Model | Gemma 2 9B IT |
| Accelerator | NVIDIA L4 (1×) |
| Time to First Token (p50) | ~300 ms |
| Next Token Output Token (p50) | ~30 ms |
| Throughput | ~40 tokens/sec |
| Node type | g2-standard-12 (spot) |
| Estimated node cost | ~$0.23/hr |
| Estimated cost per 1M tokens | ~$X.XX |

*Note: Benchmarks for Gemma 2 9B IT are based on actual benchmark data on g2-standard-12 (1x L4). The deployment uses `--tensor-parallel-size 1` and has Queued Provisioning (DWS) enabled to handle accelerator availability.*

## Enabled Features
- [x] Workload Identity
- [x] VPC-native networking
- [x] Private cluster + Cloud NAT
- [ ] Binary Authorization
- [ ] Confidential GKE Nodes
- [ ] Vertical / Horizontal Pod Autoscaler
- [ ] Cluster Autoscaler / Node Auto-provisioning
- [x] DWS + Kueue (accelerator templates)
- [x] GPU node pool with driver auto-install
- [x] Config Connector resources: ContainerCluster, ContainerNodePool, ComputeNetwork, ComputeSubnetwork, StorageBucket, StorageBucketIAMMember, IAMServiceAccount, IAMPolicyMember, ComputeRouter, ComputeRouterNAT
