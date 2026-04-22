<!--
Copyright 2026 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

# Verification Plan: High-Performance GCS FUSE with Local SSD Caching

## Objective
Verify that GKE successfully mounts a GCS bucket via FUSE, configures Local SSD as a cache, and enables vLLM to serve models from this cache.

## Infrastructure Verification
1.  **Cluster Config**: Verify `gcsFuseCsiDriverConfig` is enabled.
2.  **Node Config**: Verify nodes have 1x Local SSD attached and it is used for ephemeral storage.
3.  **Timeouts**: Verify that explicit `timeouts` (30m) are set on all node pools in Terraform.
4.  **GPU Config**: Verify NVIDIA L4 GPUs are present and drivers are installed (via `nvidia-smi`).

## Workload Verification
1.  **Pod Status**: Verify the `vllm-inference` pod is `Running`.
2.  **Sidecar Verification**: Verify the GCS FUSE sidecar container is injected.
3.  **Mount Verification**: `kubectl exec` into the container and verify `/models` is mounted as `fuse.gcsfuse`.
4.  **Cache Verification**:
    - Check the sidecar logs for "file cache" initialization.
    - Verify that the sidecar has access to the ephemeral storage (Local SSD).

## Performance Test (Conceptual)
1.  **First Run**: Measure time to load a model (e.g., 5GB) from GCS.
2.  **Second Run (Scale up)**: Scale deployment to 2 replicas on the same node.
3.  **Verification**: The second pod should report significantly faster model load times by reading from the Local SSD cache.

## Automated Validation (`validate.sh`)
The `validate.sh` script will:
- Check for the existence of the cluster and node pool.
- Verify the `vllm-inference` deployment is healthy.
- Check for the `gke-gcsfuse/volumes: "true"` annotation.
- Run a basic health check against the vLLM API.
