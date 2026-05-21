#!/usr/bin/env bash
set -eo pipefail

echo "===================================================="
echo "Validating GKE & Online Boutique Config Connector Deployment"
echo "===================================================="

# 1. Wait for Config Connector GCP Resources to be Ready
echo "Waiting for Network, Subnet, Cluster, and NodePool resources to be Ready..."
kubectl wait --for=condition=Ready computenetwork/online-boutique-micr-net --timeout=300s
kubectl wait --for=condition=Ready computesubnetwork/online-boutique-micr-subnet --timeout=300s
kubectl wait --for=condition=Ready containercluster/online-boutique-micr-cluster --timeout=1200s
kubectl wait --for=condition=Ready containernodepool/online-boutique-micr-pool --timeout=1200s

# 2. Get Credentials for the newly provisioned GKE cluster
echo "Fetching GKE cluster credentials..."
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"
gcloud container clusters get-credentials online-boutique-micr-cluster --region us-central1 --project "${PROJECT_ID}"

# 3. Wait for the Workload to be fully rolled out on the target GKE cluster
echo "Waiting for microservices deployments to be rolled out..."
kubectl rollout status deployment/redis-cart -n online-boutique --timeout=300s
kubectl rollout status deployment/cartservice -n online-boutique --timeout=300s
kubectl rollout status deployment/productcatalogservice -n online-boutique --timeout=300s
kubectl rollout status deployment/currencyservice -n online-boutique --timeout=300s
kubectl rollout status deployment/shippingservice -n online-boutique --timeout=300s
kubectl rollout status deployment/recommendationservice -n online-boutique --timeout=300s
kubectl rollout status deployment/checkoutservice -n online-boutique --timeout=300s
kubectl rollout status deployment/paymentservice -n online-boutique --timeout=300s
kubectl rollout status deployment/emailservice -n online-boutique --timeout=300s
kubectl rollout status deployment/adservice -n online-boutique --timeout=300s
kubectl rollout status deployment/frontend -n online-boutique --timeout=300s

# 4. Functional Verification Test
echo "Performing functional verification..."

# Test: Run a curl test inside the GKE cluster to hit the frontend and verify it renders the home page.
# This proves the full network mesh and all backend services are healthy.
echo "Running curl test inside the cluster..."
kubectl run curl-test --namespace online-boutique --image=curlimages/curl:8.2.1 --restart=Never --overrides='{"spec": {"activeDeadlineSeconds": 60}}' -- curl -sS http://frontend:80/

# Wait for curl-test pod to finish (Complete or Failed)
kubectl wait --namespace online-boutique --for=condition=Complete pod/curl-test --timeout=60s || true

# Check the logs of curl-test pod
LOGS=$(kubectl logs -n online-boutique curl-test)
kubectl delete pod curl-test -n online-boutique

if echo "$LOGS" | grep -q "<title>Online Boutique</title>"; then
  echo "SUCCESS: Online Boutique frontpage returned 200 OK and valid HTML!"
else
  echo "ERROR: Online Boutique frontpage did not render correctly."
  echo "Fetched content logs:"
  echo "$LOGS"
  exit 1
fi

echo "===================================================="
echo "All validations passed successfully!"
echo "===================================================="
