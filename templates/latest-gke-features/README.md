# Template: Latest GKE Features Template

## Overview
This template demonstrates some of the latest and most advanced features of Google Kubernetes Engine (GKE), released in 2024, 2025, and 2026. It showcases both cluster-level infrastructure improvements and modern workload deployment patterns.

## Latest Features Included

### Cluster Features
- **GKE Gateway API**: Enabled by default (`CHANNEL_STANDARD`), providing a modern, expressive way to manage load balancing.
- **Node Pool Auto-provisioning (NAP)**: Automatically creates and manages node pools based on workload requirements.
- **Image Streaming (GCFS)**: Significantly reduces container startup times by streaming image data on-demand.
- **Enterprise Security Posture**: Advanced vulnerability scanning and security monitoring (Vulnerability Enterprise).
- **Spot VMs**: Cost-optimized compute for fault-tolerant workloads (supported via NAP and standard pools).

### Workload Features
- **Native Sidecar Containers**: Leveraging Kubernetes 1.29+ "Sidecar Containers" feature (init containers with `restartPolicy: Always`).
- **GKE Gateway Controller**: Using `Gateway` and `HTTPRoute` resources instead of legacy Ingress.
- **Pod Topology Spread Constraints**: Modern scheduling to ensure high availability across hostnames and zones.

## Template Paths

### Terraform + Helm (`terraform-helm/`)
- Provisions a VPC-native, private GKE Standard cluster with NAP and Gateway API enabled.
- Deploys a workload using a Helm chart that utilizes native sidecars and is exposed via GKE Gateway.

### Config Connector (`config-connector/`)
- Demonstrates a Kubernetes-native way to provision the core infrastructure (VPC, Cluster, NodePool).
- Includes Kubernetes manifests for the workload (`config-connector-workload/`) to demonstrate functional parity for users who prefer not to use Helm.

## Deployment Paths

### Terraform + Helm (`terraform-helm/`)

1.  **Provision Infrastructure & Workload**:
    ```bash
    cd terraform-helm
    terraform init -backend-config="bucket=<TF_STATE_BUCKET>" -backend-config="prefix=templates/latest-gke-features/terraform-helm"
    terraform apply -var="project_id=<PROJECT_ID>"
    ```

2.  **Verify Deployment**:
    Run the automated validation script:
    ```bash
    ./validate.sh
    ```

### Config Connector (`config-connector/`)

1.  **Apply Infrastructure Manifests**:
    Apply the core infrastructure manifests to your Config Connector management namespace:
    ```bash
    kubectl apply -f config-connector/network.yaml
    kubectl apply -f config-connector/nat.yaml
    kubectl apply -f config-connector/cluster.yaml
    kubectl apply -f config-connector/nodepool.yaml
    ```

2.  **Wait for Infrastructure**:
    Monitor the status of the cluster and node pool until they are `Ready`:
    ```bash
    kubectl wait --for=condition=Ready containercluster latest-gke-features-kcc -n forge-management --timeout=20m
    kubectl wait --for=condition=Ready containernodepool latest-gke-features-kcc-pool -n forge-management --timeout=15m
    ```

3.  **Deploy Workload**:
    Once the cluster is ready, get credentials and apply the workload manifests directly to the **workload cluster**. This will create the `latest-features` namespace and all required resources:
    ```bash
    gcloud container clusters get-credentials latest-gke-features-kcc --region us-central1 --project <PROJECT_ID>
    kubectl apply -f config-connector-workload/workload.yaml
    ```

4.  **Verify Advanced Features**:

    **Sidecar Verification**:
    Verify that the \`logger-sidecar\` is running as a native sidecar in the \`latest-features\` namespace:
    ```bash
    POD_NAME=$(kubectl get pods -n latest-features -l app.kubernetes.io/name=latest-features-workload -o jsonpath='{.items[0].metadata.name}')
    kubectl get pod $POD_NAME -n latest-features -o jsonpath='{.spec.initContainers[0].restartPolicy}'
    # Expected output: Always
    ```


    **Gateway API Verification**:
    Verify the Gateway is `Programmed` and reachable via its external IP:
    ```bash
    kubectl wait --for=condition=Programmed gateway/latest-features-gateway -n latest-features --timeout=10m
    GATEWAY_IP=$(kubectl get gateway latest-features-gateway -n latest-features -o jsonpath='{.status.addresses[0].value}')
    curl -I http://$GATEWAY_IP/
    ```

    **Image Streaming (GCFS) Verification**:
    Verify GCFS is enabled on the node pool:
    ```bash
    gcloud container node-pools describe latest-gke-features-kcc-pool \
      --cluster latest-gke-features-kcc \
      --region us-central1 \
      --format="value(config.gcfsConfig.enabled)"
    # Expected output: True
    ```

## Performance & Cost Estimates

| Resource | Config | Estimated cost |
|---|---|---|
| Node pool | e2-standard-4 (1 node), spot | ~$0.04/hr |
| Load balancer | GKE Gateway (L7 GCLB) | ~$0.025/hr |
| **Total (estimated)** | | **~$0.07/hr** |

## Cleanup

### Terraform Path
```bash
cd terraform-helm && terraform destroy -var="project_id=<PROJECT_ID>"
```

### Config Connector Path
```bash
# Delete workload from workload cluster
kubectl delete -f config-connector-workload/workload.yaml

# Delete infrastructure from management cluster
kubectl delete -f config-connector/nodepool.yaml -n forge-management
kubectl delete -f config-connector/cluster.yaml -n forge-management
kubectl delete -f config-connector/nat.yaml -n forge-management
kubectl delete -f config-connector/network.yaml -n forge-management
```

## Validation Record

|  | Terraform + Helm | Config Connector |
| --- | --- | --- |
| **Status** | success | success |
| **Date** | 2026-04-18 | 2026-04-18 |
