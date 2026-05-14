# Kubernetes Autoscaler Example

This example demonstrates how to deploy a simple application with autoscaling enabled on Kubernetes.

## Prerequisites

*   A Kubernetes cluster
*   kubectl configured to connect to your cluster
*   Helm (optional, for easier deployment)

## Deployment

1.  **Deploy the application:**

    You can deploy the application using kubectl or Helm.

    **Using kubectl:**

    ```bash
    kubectl apply -f deployment.yaml
    kubectl apply -f service.yaml
    kubectl apply -f hpa.yaml
    ```

    **Using Helm:**

    ```bash
    helm install my-app .
    ```

2.  **Configure the Horizontal Pod Autoscaler (HPA):**

    The `hpa.yaml` file defines the HPA configuration.  Adjust the `minReplicas`, `maxReplicas`, and target CPU utilization as needed.

3.  **Test the autoscaling:**

    Generate load on the application to trigger the autoscaling.  You can use a tool like `hey` or `loadtest`.

    ```bash
    hey -n 10000 -c 100 http://<your-service-ip>
    ```

4.  **Monitor the autoscaling:**

    Use `kubectl get hpa` to monitor the HPA status.  You should see the number of replicas increase as the load increases.

## Files

*   `deployment.yaml`:  Defines the application deployment.
*   `service.yaml`:  Defines the application service.
*   `hpa.yaml`:  Defines the Horizontal Pod Autoscaler.

## Notes

*   This is a simple example and may need to be adjusted for your specific application.
*   Consider using more sophisticated autoscaling metrics, such as memory utilization or custom metrics.
