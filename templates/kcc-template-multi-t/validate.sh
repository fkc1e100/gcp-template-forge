#!/usr/bin/env bash
set -euo pipefail

echo "Running validation for Multi-Tenant Ray with Kueue..."

echo "Waiting for webhooks and controllers to be ready..."
sleep 15

# Use randomized names to avoid cluster-scoped resource collisions in parallel CI runs
FLAVOR_NAME="test-flavor-${RANDOM}"
CQ_NAME="test-cq-${RANDOM}"
LQ_NAME="test-lq-${RANDOM}"
JOB_NAME="test-rayjob-${RANDOM}"

echo "Deploying Kueue queues for test..."
cat <<EOF | kubectl apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: ${FLAVOR_NAME}
spec:
  nodeLabels: {}
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: ${CQ_NAME}
spec:
  namespaceSelector: {}
  resourceGroups:
  - coveredResources: ["cpu", "memory"]
    flavors:
    - name: ${FLAVOR_NAME}
      resources:
      - name: "cpu"
        nominalQuota: 100
      - name: "memory"
        nominalQuota: 200Gi
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  name: ${LQ_NAME}
  namespace: default
spec:
  clusterQueue: ${CQ_NAME}
EOF

echo "Deploying test RayJob to the equitable queue..."
cat <<EOF | kubectl apply -f -
apiVersion: ray.io/v1
kind: RayJob
metadata:
  name: ${JOB_NAME}
  namespace: default
  labels:
    kueue.x-k8s.io/queue-name: ${LQ_NAME}
spec:
  entrypoint: python -c "print('Hello from Ray + Kueue!')"
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
      - replicas: 1
        minReplicas: 1
        maxReplicas: 1
        groupName: small-group
        rayStartParams: {}
        template:
          spec:
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

echo "Waiting for RayJob to start and complete (timeout 5 minutes)..."
for i in {1..30}; do
  STATUS=$(kubectl get rayjob ${JOB_NAME} -o jsonpath='{.status.jobDeploymentStatus}' 2>/dev/null || echo "Unknown")
  if [ "$STATUS" == "Complete" ] || [ "$STATUS" == "Successful" ]; then
    echo "RayJob completed successfully!"
    exit 0
  fi
  echo "Current status: $STATUS. Waiting 10s..."
  sleep 10
done

echo "RayJob failed to complete in time. Dumping info:"
kubectl get pods -A
kubectl describe rayjob ${JOB_NAME}
kubectl describe clusterqueue ${CQ_NAME}
exit 1
