# GKE GCS FUSE Inference Cache

> High-performance AI inference with GCS FUSE + Local SSD caching for fast model loading on L4 GPUs

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Architecture

This template demonstrates how to achieve high-performance model loading on GKE using **Cloud Storage FUSE** with **Local SSD caching**. This pattern is ideal for AI inference workloads (like vLLM) that need to load large models (100GB+) quickly while minimizing egress costs and Persistent Disk overhead.

