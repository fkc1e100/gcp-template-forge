# Latest GKE Features Template

This template showcases the latest GKE and Kubernetes features, including Native Sidecar Containers and Pod Topology Spread Constraints.

## Features

- **Native Sidecar Containers** — Uses the Kubernetes 1.29+ feature where sidecars are defined in `initContainers` with `restartPolicy: Always`.
- **Pod Topology Spread Constraints** — Ensures high availability by spreading pods across nodes and zones.
- **GKE Gateway API** — Demonstrates modern L7 load balancing.
- **Private GKE Cluster** — Secure infra with Cloud NAT.

## Deployment Paths

### Terraform + Helm (`terraform-helm/`)

#### Deployment Commands
```bash
cd terraform-helm
terraform init -backend-config="bucket=<TF_STATE_BUCKET>" -backend-config="prefix=templates/latest-gke-features/terraform-helm"
terraform apply -var="project_id=<PROJECT_ID>"
```

#### Verification
```bash
gcloud container clusters get-credentials gke-latest-tf --region us-central1
kubectl get pods
# Check for sidecar container in the pod spec
kubectl get pod <POD_NAME> -o jsonpath='{.spec.initContainers}'
```

---

### Config Connector (`config-connector/`)

#### Deployment Commands
```bash
kubectl apply -f config-connector/
```

#### Verification
```bash
kubectl wait --for=condition=Ready containercluster gke-latest-kcc --timeout=20m
kubectl get gateway latest-features-gateway
```

## Performance & Cost Estimates
Using native sidecars reduces complexity in lifecycle management. Pod topology spread constraints ensure better availability during zonal outages.

## Cleanup
```bash
# Terraform
terraform destroy

# KCC
kubectl delete -f config-connector/
```
