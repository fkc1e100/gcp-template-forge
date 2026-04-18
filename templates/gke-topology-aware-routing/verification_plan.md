# Verification Plan: GKE Topology-Aware Routing

This plan outlines how to verify that Topology-Aware Routing is correctly configured and preferring intra-zone traffic.

## Prerequisites

- GKE cluster deployed with the `gke-topology-aware-routing` template.
- Workloads (frontend and backend) deployed.
- `kubectl` configured to access the cluster.

## Step 1: Verify Topology Spread

Check that frontend and backend pods are distributed across different nodes. Since this is a regional cluster, GKE will distribute nodes across zones, and the `topologySpreadConstraints` will ensure pods are spread across those zones.

```bash
# Check frontend pods distribution
kubectl get pods -l app=frontend -o wide

# Check backend pods distribution
kubectl get pods -l app=backend -o wide
```

To see the exact zone for each pod, you can correlate the `NODE` name with the node's topology label:
```bash
kubectl get nodes -L topology.kubernetes.io/zone
```
Each pod should be scheduled on a node in a different zone.

## Step 2: Verify Service Annotations

Verify that the services have the topology-mode annotation.

```bash
kubectl get svc frontend -o jsonpath='{.metadata.annotations.service\.kubernetes\.io/topology-mode}'
kubectl get svc backend -o jsonpath='{.metadata.annotations.service\.kubernetes\.io/topology-mode}'
```

Both should return `Auto`.

## Step 3: Inspect EndpointSlices

Check the `EndpointSlice` for the `backend` service. Kubernetes should have added hints to the endpoints.

```bash
kubectl get endpointslices -l kubernetes.io/service-name=backend -o yaml
```

Look for `hints` in the `endpoints` list:
```yaml
endpoints:
- addresses:
  - 10.36.1.5
  conditions:
    ready: true
  hints:
    forZones:
    - name: us-central1-a
  nodeName: gke-topology-cluster-pool-123-abc
  zone: us-central1-a
```

## Step 4: Trace Traffic (The "Proof")

We will use the `whereami` container's ability to report its own zone and the zone of its upstream backend.

1.  Get the external IP of the Gateway and wait for it to be ready:
    ```bash
    kubectl get gateways external-http -o jsonpath='{.status.addresses[0].value}'
    ```
    
    If the IP is not yet assigned, wait a few minutes. You can also watch the status:
    ```bash
    kubectl get gateway external-http --watch
    ```

2.  Curl the frontend multiple times:
    ```bash
    GATEWAY_IP=$(kubectl get gateways external-http -o jsonpath='{.status.addresses[0].value}')
    # Ensure GATEWAY_IP is set
    if [ -z "$GATEWAY_IP" ]; then echo "Error: Gateway IP not found"; exit 1; fi
    
    echo "Testing endpoint http://$GATEWAY_IP/..."
    for i in {1..10}; do 
      curl -s http://$GATEWAY_IP | jq -r '"Frontend Zone: \(.zone), Backend Zone: \(.backend.zone)"'
    done
    ```

**Expected Result:**
The `zone` (frontend) and `.backend.zone` (backend) should match in almost every request. If they match, it confirms the traffic stayed within the same zone, avoiding cross-zone egress costs.

Note: Topology-Aware Routing is a "preference," not a strict requirement. If a zone is overloaded or has no healthy endpoints, traffic may still go cross-zone.
