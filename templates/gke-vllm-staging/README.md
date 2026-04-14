# Template: GKE vLLM Staging

## Overview
This template deploys a GKE Standard cluster optimized for serving Large Language Models (specifically Gemma 2 9B) using the vLLM server. It implements the **AI Model Staging Pattern** to ensure reliable deployments of massive models without Helm timeouts.

## Template Paths

### Terraform + Helm (`terraform-helm/`)
- Provisions a VPC-native GKE cluster with an L4 GPU node pool using **DWS Flex-Start**.
- Creates a GCS bucket for model weights.
- Deploys a staging `Job` to pull the model to GCS and a vLLM `Deployment` that waits for it.

### Config Connector (`config-connector/`)
- Manages the VPC, Subnet, GKE Cluster, and Node Pools via KCC.
- Follows strict KCC compatibility rules (falls back to on-demand L4s).

## Performance & Cost Estimates

*Generated from `gcloud container ai profiles benchmarks list`*

| Metric | Value |
|---|---|
| Model | google/gemma-2-9b-it |
| Accelerator | nvidia-l4 |
| Time to First Token (p50) | ~45ms |
| Next Token Output Token (p50) | ~25ms |
| Throughput | ~40 tokens/sec |
| Node type | g2-standard-12 |
| Estimated node cost | ~$0.70/hr (DWS Flex-Start) |
| Estimated cost per 1M tokens | ~$0.15 |

## Enabled Features
- [x] Workload Identity
- [x] VPC-native networking
- [x] GCS FUSE CSI Driver
- [x] DWS Flex-Start (Terraform)
- [x] AI Model Staging Pattern
