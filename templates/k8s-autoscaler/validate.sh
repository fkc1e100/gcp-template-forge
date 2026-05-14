#!/bin/bash
# This script simulates a load to trigger HPA
echo "Starting load simulation..."
kubectl scale deployment nginx-autoscale-test --replicas=10
echo "Waiting for HPA to detect load..."
sleep 60
echo "Checking HPA status..."
kubectl get hpa nginx-hpa
echo "Simulation complete."
