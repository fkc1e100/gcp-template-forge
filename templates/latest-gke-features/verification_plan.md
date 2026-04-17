# Verification Plan - Latest GKE Features

This plan outlines the steps to verify the Latest GKE Features template.

## Features to Verify
- **GKE Gateway API**: Verified by checking Gateway resource status and HTTP connectivity.
- **Native Sidecar Containers**: Verified by checking `restartPolicy: Always` on the deployment's init container.
- **Image Streaming (GCFS)**: Verified by checking the node pool configuration.
- **Node Pool Auto-provisioning (NAP)**: Verified by checking cluster autoscaling configuration.
- **Security Posture Enterprise**: Verified by checking cluster security posture config.

## Step-by-Step Verification

### 1. Provision Infrastructure
```bash
cd terraform-helm/
terraform init
terraform apply -auto-approve \
  -var="project_id=$PROJECT_ID" \
  -var="service_account=$SERVICE_ACCOUNT"
```

### 2. Run Automated Validation
Execute the `validate.sh` script to perform in-cluster tests:
```bash
./validate.sh
```

### 3. Manual Inspection
- **Gateway API**: `kubectl get gateway,httproute`
- **Sidecar**: `kubectl get pod -l app.kubernetes.io/name=latest-features-workload -o jsonpath='{.items[0].spec.initContainers[0].restartPolicy}'`
- **NAP**: `gcloud container clusters describe latest-gke-features-tf --region us-central1 --format="value(autoscaling.enableNodeAutoprovisioning)"`

### 4. Cleanup
```bash
terraform destroy -auto-approve
```
