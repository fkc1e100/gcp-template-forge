#!/usr/bin/env bash
set -euo pipefail

echo "=== Test 1: Cluster Validation ==="
gcloud container clusters get-credentials "${TF_VAR_cluster_name}" --region "${TF_VAR_region}" --project "${TF_VAR_project_id}"

echo "=== Test 5: Functional Verification (Kueue + KubeRay) ==="

echo "Adding Helm repos..."
helm repo add kueue https://kubernetes-sigs.github.io/kueue/charts
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update

echo "Installing Kueue (v0.8.0)..."
helm upgrade --install kueue kueue/kueue \
  --version v0.8.0 \
  --namespace kueue-system \
  --wait

echo "Installing KubeRay Operator (1.1.1)..."
helm upgrade --install kuberay-operator kuberay/kuberay-operator \
  --version 1.1.1 \
  --namespace ray-system \
  --wait

echo "Applying Kueue ResourceFlavor, ClusterQueue, and LocalQueue..."
cat <<EOF | kubectl apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: default-flavor-${TF_VAR_uid_suffix}
spec:
  nodeLabels:
    ray-node-type: worker
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: cluster-queue-${TF_VAR_uid_suffix}
spec:
  namespaceSelector: {}
  resourceGroups:
  - coveredResources: ["cpu", "memory"]
    flavors:
    - name: default-flavor-${TF_VAR_uid_suffix}
      resources:
      - name: "cpu"
        nominalQuota: 32
      - name: "memory"
        nominalQuota: 128Gi
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  name: local-queue-${TF_VAR_uid_suffix}
  namespace: default
spec:
  clusterQueue: cluster-queue-${TF_VAR_uid_suffix}
EOF

# Allow Kueue controllers to process the queues
sleep 10

echo "Submitting RayJob..."
cat <<EOF | kubectl apply -f -
apiVersion: ray.io/v1
kind: RayJob
metadata:
  name: ray-job-${TF_VAR_uid_suffix}
  namespace: default
  labels:
    kueue.x-k8s.io/queue-name: local-queue-${TF_VAR_uid_suffix}
spec:
  entrypoint: python -c "import ray; ray.init(); print('Cluster resources:', ray.cluster_resources())"
  runtimeEnvYAML: |
    pip:
      - requests==2.31.0
  rayClusterSpec:
    rayVersion: '2.9.0'
    headGroupSpec:
      rayStartParams:
        dashboard-host: '0.0.0.0'
      template:
        spec:
          containers:
          - name: ray-head
            image: rayproject/ray:2.9.0
            resources:
              limits:
                cpu: "1"
                memory: "2Gi"
              requests:
                cpu: "1"
                memory: "2Gi"
    workerGroupSpecs:
    - groupName: worker-group
      replicas: 1
      minReplicas: 1
      maxReplicas: 2
      rayStartParams: {}
      template:
        spec:
          nodeSelector:
            ray-node-type: worker
          containers:
          - name: ray-worker
            image: rayproject/ray:2.9.0
            resources:
              limits:
                cpu: "1"
                memory: "2Gi"
              requests:
                cpu: "1"
                memory: "2Gi"
EOF

echo "Waiting for RayJob to complete..."
MAX_RETRIES=60
for ((i=1; i<=MAX_RETRIES; i++)); do
  STATUS=$(kubectl get rayjob ray-job-${TF_VAR_uid_suffix} -o jsonpath='{.status.jobStatus}' 2>/dev/null || echo "Pending")
  echo "RayJob Status: ${STATUS}"
  
  if [ "$STATUS" == "SUCCEEDED" ]; then
    echo "✅ RayJob completed successfully!"
    exit 0
  fi
  
  if [ "$STATUS" == "FAILED" ]; then
    echo "❌ RayJob failed."
    kubectl get rayjob ray-job-${TF_VAR_uid_suffix} -o yaml
    exit 1
  fi
  
  sleep 10
done

echo "❌ RayJob timed out waiting for SUCCEEDED state."
kubectl get rayjob ray-job-${TF_VAR_uid_suffix} -o yaml
kubectl get events
exit 1
