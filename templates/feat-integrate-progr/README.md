# Dashboard Progress SSE (feat-integrate-progr)

This template provisions a GKE cluster using Config Connector and deploys a mock dashboard web server.
It verifies Server-Sent Events (SSE) functionality to serve progress state updates in real-time.

## Workload Architecture
- **ConfigMap**: Contains a lightweight Python HTTP server that streams SSE data on the `/events` endpoint.
- **Deployment**: Runs a Python 3.9 pod mounting the script and serving requests.
- **Service**: An external LoadBalancer routing traffic to the Python application.

## Validation
The `validate.sh` script waits for the LoadBalancer to provision its external IP, and then performs a functional test by querying both the root path (HTTP 200) and the `/events` path to assert that `data:` chunks are actively returned.

## Deployment Path (KCC)
This repository includes a Config Connector [KCC] path only as requested by the task.

1. `kubectl apply -f config-connector/` (applies to KCC management cluster)
2. CI waits for infrastructure to become Ready.
3. `kubectl apply -f config-connector-workload/` (applies to the provisioned template cluster)
4. Run `validate.sh` against the provisioned cluster.
