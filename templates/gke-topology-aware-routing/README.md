# GKE Topology-Aware Routing

This template demonstrates how to configure Topology-Aware Hints in GKE to reduce cross-zone traffic costs and improve latency by routing traffic to backends in the same zone.

## Architecture

- **Multi-Zonal GKE Cluster** — Nodes spread across multiple zones in a region.
- **Topology-Aware Routing** — Enabled on Services using the `service.kubernetes.io/topology-mode: Auto` annotation.
- **Frontend/Backend Workload** — A two-tier application using `whereami` to demonstrate zonal routing.
- **Gateway API** — External L7 load balancing using GKE Gateway controller.

## Deployment Paths

### Terraform + Helm (`terraform-helm/`)

#### Deployment Commands
```bash
cd terraform-helm
terraform init -backend-config="bucket=<TF_STATE_BUCKET>" -backend-config="prefix=templates/gke-topology-aware-routing/terraform-helm"
terraform apply -var="project_id=<PROJECT_ID>"
```

#### Verification
```bash
gcloud container clusters get-credentials gke-topology-tf --region us-central1
kubectl get service frontend -o yaml # Check for topology-mode annotation
```

---

### Config Connector (`config-connector/`)

#### Deployment Commands
```bash
kubectl apply -f config-connector/
```

#### Verification
```bash
kubectl wait --for=condition=Ready containercluster gke-topology-kcc --timeout=20m
kubectl get gateway external-http
# Verify topology hints in endpoint slices
kubectl get endpointslices -l kubernetes.io/service-name=backend
```

## Performance & Cost Estimates
Topology-aware routing reduces inter-zonal data transfer costs, which is typically $0.01/GB. For high-traffic applications, this can result in significant savings.

## Cleanup
```bash
# Terraform
terraform destroy

# KCC
kubectl delete -f config-connector/
```
