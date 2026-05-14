# K8s Autoscaler Test
This template deploys a GKE cluster with a pre-configured Nginx deployment and HPA.

## Usage
1. Deploy Terraform infra.
2. Apply Kubernetes manifests.
3. Run `./validate.sh` to trigger CPU load and observe scaling.
