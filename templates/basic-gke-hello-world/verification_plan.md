# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Verification Plan - Basic GKE Hello World

This plan outlines the steps to verify both the Terraform + Helm and Config Connector deployment paths.

## Path 1: Terraform + Helm

### Deployment
```bash
cd terraform-helm/
terraform init
terraform apply -auto-approve
```

### Verification
1. **Cluster Health:**
   ```bash
   gcloud container clusters describe gke-basic-tf --region us-central1 --format="value(status)"
   ```
2. **Workload Health:**
   ```bash
   gcloud container clusters get-credentials gke-basic-tf --region us-central1
   kubectl get pods -l app.kubernetes.io/name=hello-world
   ```
3. **Endpoint Interaction:**
   ```bash
   # Get LoadBalancer IP
   SERVICE_IP=$(kubectl get svc -l app.kubernetes.io/name=hello-world -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
   curl -sf http://${SERVICE_IP}:80/
   ```

### Teardown
```bash
terraform destroy -auto-approve
```

## Path 2: Config Connector

### Deployment
1. **Infrastructure**:
   ```bash
   # Apply KCC manifests (GCP resources) to forge-management namespace on management cluster
   kubectl apply -f config-connector/ -n forge-management
   ```
2. **Workload**:
   Wait for cluster readiness, then switch context to the new cluster and apply the workload:
   ```bash
   gcloud container clusters get-credentials basic-gke-hello-world --region us-central1
   kubectl apply -f config-connector-workload/workload.yaml
   ```

### Verification
1. **Resource Readiness:**
   ```bash
   # Check KCC resources in management cluster
   kubectl wait --for=condition=Ready containercluster/basic-gke-hello-world -n forge-management --timeout=30m
   ```
2. **Workload & Endpoint:**
   ```bash
   export CLUSTER_NAME=basic-gke-hello-world
   ./validate.sh
   ```

### Teardown
```bash
# Delete workload from target cluster
kubectl delete -f config-connector-workload/workload.yaml
# Delete KCC manifests from management cluster
kubectl delete -f config-connector/ -n forge-management
```
