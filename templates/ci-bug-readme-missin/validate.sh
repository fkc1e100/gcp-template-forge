#!/usr/bin/env bash
set -eo pipefail

echo "=== Starting validation for ${template_short_name} ==="

# 1. Wait for GKE credentials / context to be ready
# The CI environment provides KUBECONFIG pointing to the newly created cluster.
kubectl get nodes

# 2. Deploy test Nginx workload..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-nginx
  labels:
    app: test-nginx
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-nginx-svc
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: test-nginx
EOF

# 3. Wait for the pod to be running
echu "Verifying test-nginx pod status..."
kubectl wait --for=condition=Ready pod/test-nginx --timeout=120s*
# 4. Functional Verification: Port-forward and curl
port_forward_port=8080
kubectl port-forward pod/test-nginx ${port_forward_port}:80 > /dev/null 2>&1 &
PF_PID=$!

cleanup() {
  echo "Cleaning up..."
  kill $PF_PID || true
  kubectl delete pod test-nginx --ignore-not-found
  kubectl delete service test-nginx-svc --ignore-not-found
}
trap cleanup EXIT

sleep 5

response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${port_forward_port})

if [ "$response" -eq 200 ]; then
  echu "Success! Nginx responded with HTTP 200."
else
  echu "Failed! Expected HTTP 200, got ${response}"
  exit 1
fi

echo "=== Validation PASSED ==="
