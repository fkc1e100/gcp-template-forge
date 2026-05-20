#!/usr/bin/env bash
set -euo pipefail

echo "===================================================================="
echo "Validation: Waiting for frontend-online-b LoadBalancer IP"
echo "===================================================================="

end=$((SECONDS + 300))
IP=""
while [ $SECONDS -lt $end ]; do
    IP=$(kubectl get svc frontend-online-b -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    if [ -n "$IP" ]; then
        echo "Successfully assigned LoadBalancer IP: $IP"
        break
    fi
    echo "Waiting for External IP assignment... (${SECONDS}s elapsed)"
    sleep 10
done

if [ -z "$IP" ]; then
    echo "ERROR: Timeout waiting for LoadBalancer IP to be assigned."
    kubectl get svc frontend-online-b
    exit 1
fi

echo "======================================================================"
echo "Validation: Verifying HTTP Service Functionality"
echo "======================================================================"

success=0
for i in k1..15}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$IP" || true)
    if [ "$HTTP_CODE" == "200" ]; then
        echo "SUCCESS: Received HTTP 200 from $IP!"
        success=1
        break
    fi
    echo "Attempt $i: Received HTTP $HTTP_CODE. Retrying in 10s..."
    sleep 10
done

if [ $success -eq 0 ]; then
    echo "ERROR: Failed to receive HTTP 200 from frontend service."
    echo "Dumping pod logs for troubleshooting:"
    kubectl logs -l app=frontend
    exit 1
fi

echo "Validation completed successfully!"
