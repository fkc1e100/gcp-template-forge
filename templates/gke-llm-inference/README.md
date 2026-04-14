# Template: GKE LLM Inference (Customer Support Chatbot)

## Overview
This template provisions a GKE Standard cluster optimized for LLM inference using NVIDIA L4 GPUs. It deploys the vLLM serving framework to host a Qwen 2.5 1.5B Instruct model, providing an OpenAI-compatible API endpoint. Model weights are loaded from a dedicated Cloud Storage bucket via the GCS FUSE CSI driver, ensuring separation of infrastructure, code, and large model assets.

## Template Paths

### Terraform + Helm (`terraform-helm/`)
- Provisions a VPC, a GKE Standard cluster with GCS FUSE CSI driver enabled.
- Creates an L4 GPU node pool using standard autoscaling for reliable provisioning.
- Creates a GCS bucket for model weights and configures Workload Identity.
- Deploys vLLM via a local Helm chart, exposing it through a LoadBalancer service.

### Config Connector (`config-connector/`)
- Manages the same infrastructure (VPC, GKE, Node Pools, GCS Bucket, IAM) using K8s-native Config Connector resources.
- Demonstrates how to manage high-performance ML infrastructure as code within the Kubernetes control plane.

## Cluster Details
- **Type**: GKE Standard (Required for DWS Flex-Start and custom node pool config)
- **Release channel**: RAPID
- **Node pools**: 
  - `cpu-pool`: `e2-standard-4` (spot) for system workloads.
  - `gpu-pool`: `g2-standard-12` with 1x NVIDIA L4 GPU.
- **Networking**: VPC-native, private cluster with Cloud NAT (optional, defaults to public for simplicity in this template).

## Workload Details
- **Application**: vLLM (OpenAI-compatible API server)
- **Model**: Qwen/Qwen2.5-1.5B-Instruct
- **Access**: LoadBalancer Service (Port 80 -> 8000)
- **Weights**: Mounted from GCS at `/data` via GCS FUSE.

## Enabled Features
- [x] Workload Identity
- [x] VPC-native networking
- [x] GCS FUSE CSI driver
- [x] GPU node pool with driver auto-install (GKE managed)
- [x] Config Connector resources: ContainerCluster, ContainerNodePool, StorageBucket, IAMPolicyMember

## Performance & Cost Estimates

*Generated from `gcloud container ai profiles benchmarks list`*

| Metric | Value |
|---|---|
| Model | Qwen/Qwen2.5-1.5B-Instruct |
| Accelerator | NVIDIA L4 (1×) |
| Output Tokens/sec (at 1 QPS) | ~210 |
| Next Token Output Token (p50) | ~25 ms |
| Estimated node cost (g2-standard-12) | ~$0.80/hr |
| Estimated cost per 1M Output Tokens | ~$0.80 |

*Note: Costs are estimates based on us-central1 pricing. Actual costs may vary.*
# Trigger
