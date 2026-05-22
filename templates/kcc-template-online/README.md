# kcc-template-online

This template provides a complete Google Cloud Infrastructure as Code setup using **Google Cloud Config Connector (KCC)** to deploy a standard robust online service architecture on GKE.

## Resources Created

- **ComputeNetwork & ComputeSubnetwork**: Private VPC and custom regional subnet.
- **ContainerCluster**: Google Kubernetes Engine standard cluster with Workload Identity.
- **ContainerNodePool**: Custom node pool scaled to host microserviced web apps.
- **K8s Workloads**: A highly available online boutique style web frontend deployment with a public LoadBalancer.

## Deployment & Verification

The template is designed to structure resources with standard GCC / KCC specifications. 

Our custom dynamic `validate.sh` will:
1. Verify Kube credentials and cluster connectivity.
2. Confirm successful deployment of Kubernetes workloads.
3. Poll until load balancer ingress IP is assigned.
4. Issue HTTP requests to prove the app is live with correct response output.
