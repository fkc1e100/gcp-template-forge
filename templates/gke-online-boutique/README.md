# GKE Online Boutique Reference Architecture

This reference architecture demonstrates how to deploy the classic **Google Cloud Online Boutique** microservices application securely on Google Kubernetes Engine (GKE) in a VPC-Native environment.

It supports two deployment paths:
1. **Path 1: Terraform + Helm**: Deploys the GKE infrastructure via Terraform HCL and installs the workloads via Helm charts.
2. **Path 2: Config Connector (KCC)**: Deploys the GKE infrastructure declaratively using Kubernetes-native KCC resource manifests.

---

## Architecture Overview
* **Network**: Dedicated custom VPC and private subnets.
* **Kubernetes**: regional GKE cluster with spot node pools for maximum cost-efficiency.
* **Workloads**: 11 microservices (frontend, cart, checkout, etc.) connected to a Redis cart backend.

---

## Deployment Instructions

### Path 1: Terraform + Helm

```bash
cd templates/gke-online-boutique/terraform-helm

# Initialize and apply HCL
terraform init -backend-config="bucket=YOUR_TF_STATE_BUCKET" -backend-config="prefix=templates/gke-online-boutique"
terraform apply -var="project_id=YOUR_PROJECT_ID" -var="service_account=YOUR_NODE_SA"
```

---

### Path 2: Config Connector (KCC)

```bash
cd templates/gke-online-boutique/config-connector

# Apply declarative manifests to host cluster
kubectl apply -n forge-management -f .
```

---

## Verification

Run the combined validation script from the root directory to verify GKE API routing, workload pod readiness, and frontend load balancer responses:

```bash
export PROJECT_ID="YOUR_PROJECT_ID"
export CLUSTER_NAME="gke-online-boutique-tf"
export REGION="us-central1"

chmod +x templates/gke-online-boutique/validate.sh
./templates/gke-online-boutique/validate.sh
```

---

<!-- CI: validation record appended here by ci-post-merge.yml — do not edit below this line manually -->
