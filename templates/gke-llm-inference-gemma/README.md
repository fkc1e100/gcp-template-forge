# Template: GKE LLM Inference — Gemma 2

## Overview
This template deploys a production-oriented LLM inference workload on GKE using Gemma 2 9B IT and the vLLM serving framework. It leverages L4 GPUs for cost-effective performance and GCS FUSE for efficient model weight loading.

## Template Paths

### Terraform + Helm (`terraform-helm/`)
- Provisions a dedicated VPC with Slot 2 CIDRs.
- Deploys a GKE Standard cluster with a GPU node pool (NVIDIA L4).
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

*Generated from `gcloud container ai profiles benchmarks list` (using Gemma 2 2B IT as reference for L4)*

| Metric | Value |
|---|---|
| Model | Gemma 2 9B IT (Reference: 2B IT) |
| Accelerator | NVIDIA L4 (1×) |
| Time to First Token (p50) | ~600 ms |
| Next Token Output Token (p50) | ~94 ms |
| Throughput | ~1458 tokens/sec |
| Node type | g2-standard-12 (spot) |
| Estimated node cost | ~$0.23/hr |
| Estimated cost per 1M tokens | ~$0.14 |

*Note: Benchmarks for Gemma 2 9B IT were specifically requested but are currently returning 404 in the sandbox environment. The above figures are actual benchmarks for Gemma 2 2B IT on the same L4 accelerator to provide a realistic baseline.*

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
