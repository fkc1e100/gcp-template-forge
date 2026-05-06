# GKE Topology-Aware Routing

> Minimize cross-zone egress costs using Topology-Aware Routing hints in multi-zonal GKE clusters

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->

## Architecture

This template demonstrates how to optimize cross-zone egress costs in GKE using **Topology-Aware Routing**. In multi-zonal GKE clusters, network traffic between pods in different zones incurs cross-zone egress charges. Topology-Aware Routing (via Topology-Aware Hints) allows Kubernetes to prefer routing traffic to endpoints within the same zone as the source pod.

This template provisions:

- **VPC Network** — Isolated VPC with secondary CIDR ranges for pods and services.
- **GKE Cluster** — Regional cluster (`gke-topo-routing`) with Gateway API enabled.
- **Workload** — Frontend and Backend microservices configured with `service.kubernetes.io/topology-mode: Auto` and Topology Spread Constraints.

### Resource Naming

| Resource | Terraform + Helm | Config Connector |
|---|---|---|
| GKE Cluster | `gke-topo-routing-<uid>-tf` | `gke-topo-routing-<uid>-kcc` |
| VPC Network | `gke-topo-routing-<uid>-tf-vpc` | `gke-topo-routing-<uid>-kcc-vpc` |
| Subnet | `gke-topo-routing-<uid>-tf-subnet` | `gke-topo-routing-<uid>-kcc-subnet` |

### Estimated Cost

| Resource | Monthly Estimate |
|---|---|
| GKE Cluster (control plane) | ~$75 |
| E2 Standard Node Pool (3x e2-standard-2 Spot) | ~$45 |
| Load Balancer | ~$18 |
| **Total** | **~$138** |

*Estimates based on sustained use in us-central1 with Spot nodes.*

---

## Deployment Paths

This template supports two deployment paths that provision equivalent infrastructure.

### Path 1: Terraform + Helm

**Prerequisites:** `terraform` ≥ 1.5, `helm` ≥ 3.10, `kubectl`, `gcloud` with ADC configured.

```bash
cd templates/gke-topology-aware-routing/terraform-helm

# Initialize
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="prefix=templates/gke-topology-aware-routing/terraform-helm"

# Apply
terraform apply -var="project_id=YOUR_PROJECT_ID"

# Get credentials
gcloud container clusters get-credentials gke-topo-routing-tf --region us-central1

# Deploy workload
helm upgrade --install release ./workload --wait
```

**Cleanup:**
```bash
helm uninstall release
terraform destroy -var="project_id=YOUR_PROJECT_ID"
```

---

### Path 2: Config Connector (KCC)

**Prerequisites:** A running GKE cluster with Config Connector installed.

```bash
cd templates/gke-topology-aware-routing/config-connector

# Apply infrastructure manifests
kubectl apply -n forge-management -f .

# Wait for readiness
kubectl wait -n forge-management --for=condition=Ready --all --timeout=3600s -f .

# Get credentials
gcloud container clusters get-credentials gke-topo-routing-kcc --region us-central1

# Deploy workload
kubectl apply -f ../config-connector-workload/
```

**Cleanup:**
```bash
kubectl delete -f ../config-connector-workload/
kubectl delete -n forge-management -f . --wait=true --timeout=900s
```

---

## Verification

After deploying with either path, run the validation script:

```bash
export PROJECT_ID="YOUR_PROJECT_ID"
export CLUSTER_NAME="gke-topo-routing-tf" # or gke-topo-routing-kcc
export REGION="us-central1"
chmod +x templates/gke-topology-aware-routing/validate.sh
./templates/gke-topology-aware-routing/validate.sh
```

---

## Template Inputs

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | required |
| `region` | GCP region | `us-central1` |
| `cluster_name` | GKE cluster name | `gke-topo-routing-tf` |
| `network_name` | VPC network name | `gke-topo-routing-tf-vpc` |
