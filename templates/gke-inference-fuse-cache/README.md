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

# Template: High-Performance GCS FUSE with Local SSD Caching

## Overview
This template demonstrates how to achieve high-performance model loading on GKE using **Cloud Storage FUSE** with **Local SSD caching**. This pattern is ideal for AI inference workloads (like vLLM) that need to load large models (100GB+) quickly while minimizing egress costs and Persistent Disk overhead.

## Key Features
- **L4 GPU Acceleration**: Uses G2-standard-4 nodes with NVIDIA L4 GPUs.
- **Local NVMe SSD Caching**: Specifically configures Local SSDs to back the GCS FUSE file cache.
- **Advanced GCS FUSE Tuning**: Utilizes `fileCacheCapacity`, `fileCacheForRangeRead`, `metadataCacheTTLSeconds`, `metadataStatCacheCapacity`, and `metadataTypeCacheCapacity` for optimal performance and persistent caching.
- **Workload Identity**: Securely access GCS buckets without managing long-lived keys.
- **vLLM / Mock Inference**: Deploys a lightweight inference server configured for GCS-based model serving (uses a dummy server for CI validation speed).

## Infrastructure Architecture
- **GKE Standard Cluster**: With GCS FUSE CSI driver enabled.
- **GPU Node Pool**: `g2-standard-4` machines restricted to specific zones to ensure NVIDIA L4 and Local SSD availability.
- **GCS Bucket**: Stores the model weights.
- **Local SSD**: Attached as ephemeral storage and used by the GCS FUSE CSI driver as a dedicated cache layer.

## Template Paths

### Terraform + Helm (`terraform-helm/`)
- Provisions the full infrastructure (VPC, GKE, Bucket, IAM).
- Deploys the vLLM server via a Helm chart.

### Config Connector (`config-connector/`)
- Provisions the infrastructure using Kubernetes-native manifests.
- Includes workload manifests in `config-connector-workload/`.

## Deployment Instructions

### Prerequisites
- A GCP Project with Billing enabled.
- GPU Quota for `NVIDIA_L4_GPUS` in your chosen region (e.g., `us-central1`).
- `terraform`, `helm`, `kubectl`, and `gcloud` installed.

### Terraform + Helm Path

1.  **Provision Infrastructure**:
    ```bash
    cd terraform-helm
    terraform init
    terraform apply -var="project_id=<PROJECT_ID>"
    ```
    This will also generate a `workload/values.yaml` file.

    > **Note**: Infrastructure provisioning typically takes **up to 45 minutes**. This template uses explicit **45-minute timeouts** for node pool operations to account for GPU availability and autoscaling.

2.  **Deploy Workload**:
    ```bash
    # Replace <CLUSTER_NAME> with the output from terraform
    gcloud container clusters get-credentials <CLUSTER_NAME> --region <REGION>
    helm upgrade --install release ./workload
    ```

3.  **Verify**:
    ```bash
    cd ..
    ./validate.sh
    ```

### Config Connector Path

1.  **Apply Infrastructure**:
    
    > **Note on High Availability**: For CI optimization and quota management, the KCC `ContainerCluster` manifest uses `initialNodeCount: 1` and is restricted to a single zone. For production deployments, you should increase `initialNodeCount` to 3 and expand `nodeLocations` across multiple zones to ensure High Availability (HA).

    ```bash
    # Update <PROJECT_ID> and <REGION> placeholders in config-connector/*.yaml
    kubectl apply -f config-connector/
    ```

2.  **Wait for Readiness**:
    ```bash
    kubectl wait --for=condition=Ready containercluster gke-inf-fuse-cache -n forge-management --timeout=45m
    ```

3.  **Deploy Workload**:
    *Edit `config-connector-workload/workload.yaml` and replace `<PROJECT_ID>` and `<BUCKET_NAME>` with your actual values.*
    ```bash
    gcloud container clusters get-credentials gke-inf-fuse-cache --region <REGION>
    kubectl apply -f config-connector-workload/workload.yaml
    ```

## Security & Isolation

### Resource Management
This template includes native Kubernetes `ResourceQuota` and `LimitRange` objects in the `default` namespace to:
- **Enforce GPU Quotas**: Limits the total number of GPUs that can be requested by pods in the namespace.
- **Default Resources**: Sets reasonable default CPU and Memory requests/limits for all containers to ensure predictable scheduling.

### Network Policy
A `NetworkPolicy` (`vllm-inference-restriction`) is included to:
- **Restrict Ingress**: Only allows traffic to the vLLM inference service (port 8000) from within the same namespace (template labeled pods).
- **Isolate Workload**: Prevents unauthorized cluster-wide access to the model serving endpoint.

## Performance Benefits
By using Local SSDs for the GCS FUSE cache:
1.  **Reduced TTFT**: Models are loaded at NVMe speeds (GB/s) after the first pull.
2.  **Cost Savings**: Eliminates the need for massive `pd-ssd` or `pd-extreme` boot disks.
3.  **Scale-out Speed**: New pods on the same node benefit from the "warm" cache immediately.

## Cleanup

### Terraform
```bash
cd terraform-helm
terraform destroy -var="project_id=<PROJECT_ID>"
```

### Config Connector
```bash
kubectl delete -f config-connector-workload/workload.yaml
kubectl delete -f config-connector/
```
