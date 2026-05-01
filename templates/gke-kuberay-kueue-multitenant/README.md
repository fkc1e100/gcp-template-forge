# GKE Multitenant KubeRay + Kueue

This template demonstrates how to deploy a GKE cluster configured for multitenant GPU sharing using **KubeRay** and **Kueue**. It showcases an architecture where multiple data science teams share a single GPU node pool equitably.

## Architecture

- **GKE Cluster**: A GKE cluster with a heavily autoscaled GPU node pool (`nvidia-l4`).
- **KubeRay Operator**: Manages `RayCluster` resources to run Ray workloads natively on Kubernetes.
- **Kueue Operator**: Handles advanced queuing and resource sharing between namespaces, mitigating the "noisy neighbor" problem by managing `ClusterQueues`, `LocalQueues`, and cohorts.
- **Namespaces**: `team-a` and `team-b`.
- **Equitable Sharing**: Both teams share a Kueue cohort with strict `nominalQuota` and `borrowingLimit` rules. If Team A requests an excessive number of GPUs beyond their quota, Kueue gracefully holds their extra pods in a pending state until Team B finishes their work.

## Paths Available

### 1. Terraform + Helm

This path provisions the VPC, Subnet, and GKE cluster using Terraform, and then deploys the KubeRay operator, Kueue operator, and workload resources via Helm.

**Deployment:**
```bash
cd terraform-helm
terraform init
terraform apply
```

**Verification:**
After the infrastructure is provisioned, configure `kubectl`:
```bash
gcloud container clusters get-credentials ray-kueue-tf-cluster --region us-central1
```
Check if the operators and queues are running:
```bash
kubectl get pods -n default
kubectl get clusterqueues
kubectl get localqueues -A
kubectl get rayclusters -A
```

**Cleanup:**
```bash
terraform destroy
```

### 2. Config Connector (KCC)

This path provisions the infrastructure natively via Kubernetes manifests using Config Connector. It includes all necessary workload manifests (operators, queues, and CRDs) in the `config-connector-workload/` directory.

**Prerequisites:**
Ensure you have a management cluster with Config Connector installed and configured to manage the target project.

**Deployment:**
Apply the infrastructure manifests:
```bash
kubectl apply -f config-connector/
```

Wait for the cluster to become ready. Then, configure `kubectl` to point to the newly created workload cluster and apply the operators and workloads:
```bash
gcloud container clusters get-credentials ray-kueue-kcc-cluster --region us-central1
kubectl apply -f config-connector-workload/kueue-manifest.yaml --server-side
kubectl apply -f config-connector-workload/kuberay-operator.yaml --server-side
sleep 30 # wait for CRDs to establish
kubectl apply -f config-connector-workload/queues.yaml
kubectl apply -f config-connector-workload/ray-clusters.yaml
```

**Verification:**
```bash
kubectl get clusterqueues
kubectl get rayclusters -A
```

**Cleanup:**
```bash
kubectl delete -f config-connector-workload/
kubectl delete -f config-connector/
```
