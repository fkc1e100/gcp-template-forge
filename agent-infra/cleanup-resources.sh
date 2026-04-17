#!/bin/bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o pipefail

PROJECT="gca-gke-2025"
REGION="us-central1"
KCC_CLUSTER="krmapihost-kcc-instance"
KCC_NAMESPACE="forge-management"

echo "=== Starting Orphaned Resource Cleanup ==="
gcloud version

# 0. Quota Check
echo "=== Fetching Quotas ==="
GLOBAL_QUOTAS=$(gcloud compute project-info describe --project=$PROJECT --format="json(quotas)")
REGIONAL_QUOTAS=$(gcloud compute regions describe $REGION --project=$PROJECT --format="json(quotas)")

print_quota() {
  METRIC=$1
  SOURCE=$2
  
  USAGE=$(echo "$SOURCE" | jq -r --arg m "$METRIC" '.quotas[] | select(.metric == $m) | .usage' | cut -d'.' -f1)
  LIMIT=$(echo "$SOURCE" | jq -r --arg m "$METRIC" '.quotas[] | select(.metric == $m) | .limit' | cut -d'.' -f1)
  
  if [ -z "$USAGE" ]; then USAGE="0"; fi
  if [ -z "$LIMIT" ]; then LIMIT="0"; fi
  
  echo "  $METRIC: $USAGE / $LIMIT"
}

echo "Global Networking Quotas:"
print_quota "NETWORKS" "$GLOBAL_QUOTAS"
print_quota "FIREWALLS" "$GLOBAL_QUOTAS"
print_quota "ROUTERS" "$GLOBAL_QUOTAS"
print_quota "VPN_TUNNELS" "$GLOBAL_QUOTAS"
print_quota "SUBNETWORKS" "$GLOBAL_QUOTAS"
print_quota "FORWARDING_RULES" "$GLOBAL_QUOTAS"

echo "Regional Quotas ($REGION):"
print_quota "CPUS" "$REGIONAL_QUOTAS"
print_quota "PREEMPTIBLE_CPUS" "$REGIONAL_QUOTAS"
echo "========================"

# Get list of active/queued runs to avoid deleting their resources if GH_TOKEN is provided
ALL_ACTIVE=""
if [ -n "$GITHUB_TOKEN" ]; then
  echo "Checking for active GitHub Actions runs..."
  ACTIVE_RUNS=$(gh run list --status in_progress --json databaseId -q '.[].databaseId' 2>/dev/null || echo "")
  QUEUED_RUNS=$(gh run list --status queued --json databaseId -q '.[].databaseId' 2>/dev/null || echo "")
  ALL_ACTIVE="$ACTIVE_RUNS $QUEUED_RUNS"
  if [ -n "$ALL_ACTIVE" ]; then
    echo "Found active/queued runs: $ALL_ACTIVE. Resources matching these IDs will be skipped."
  fi
fi

# 1. Clean up KCC Clusters and other resources FIRST
echo "Connecting to Management Cluster..."
gcloud container clusters get-credentials $KCC_CLUSTER --region $REGION --project $PROJECT 2>/dev/null || echo "Failed to get KCC credentials, skipping KCC cleanup"

if kubectl cluster-info &>/dev/null; then
  echo "Deleting all KCC-managed resources with project=gcp-template-forge label..."
  KCC_TYPES="containercluster,computenetwork,computevpc,computesubnetwork,computerouter,computerouternat,computefirewall"
  KCC_RESOURCES=$(kubectl get $KCC_TYPES -n $KCC_NAMESPACE -l project=gcp-template-forge -o name | grep -v -E "repo-agent-standard|krmapihost-kcc-instance|kcc-dash-dont-delete" || true)
  
  for RES in $KCC_RESOURCES; do
    SKIP=false
    for RUN_ID in $ALL_ACTIVE; do
      if [ -n "$RUN_ID" ] && [[ "$RES" == *"$RUN_ID"* ]]; then
        echo "Skipping active resource: $RES"
        SKIP=true
        break
      fi
    done
    if [ "$SKIP" = false ]; then
      echo "Deleting orphaned KCC resource: $RES"
      kubectl delete $RES -n $KCC_NAMESPACE --wait=false || true
    fi
  done
fi

# 2. Clean up GKE Clusters (Terraform)
echo "Searching for orphaned Terraform clusters..."
TF_CLUSTERS=$(gcloud container clusters list \
  --project=$PROJECT \
  --filter="(resourceLabels.project=gcp-template-forge OR name ~ latest-gke-features- OR name ~ enterprise-gke- OR name ~ basic-gke- OR name ~ gke-) AND name != $KCC_CLUSTER" \
  --format="value(name, zone.scope())")

DELETED_CLUSTERS=false
while read -r CLUSTER C_LOC; do
  [ -z "$CLUSTER" ] && continue
  
  SKIP=false
  for RUN_ID in $ALL_ACTIVE; do
    if [ -n "$RUN_ID" ] && [[ "$CLUSTER" == *"$RUN_ID"* ]]; then
      echo "Skipping active cluster: $CLUSTER"
      SKIP=true
      break
    fi
  done
  
  if [ "$SKIP" = false ]; then
    echo "Deleting orphaned TF cluster: $CLUSTER in $C_LOC"
    gcloud beta container clusters update $CLUSTER --location=$C_LOC --project=$PROJECT --no-deletion-protection --quiet &>/dev/null || true
    gcloud container clusters delete $CLUSTER --location=$C_LOC --project=$PROJECT --quiet --async || true
    DELETED_CLUSTERS=true
  fi
done <<< "$TF_CLUSTERS"

if [ "$DELETED_CLUSTERS" = true ]; then
  echo "Waiting for clusters to be deleted (up to 10 minutes)..."
  for i in {1..20}; do
    STILL_THERE=$(gcloud container clusters list --project=$PROJECT --filter="(resourceLabels.project=gcp-template-forge OR name ~ latest-gke-features- OR name ~ enterprise-gke- OR name ~ basic-gke- OR name ~ gke-) AND name != $KCC_CLUSTER" --format="value(name)" 2>/dev/null | wc -l || echo "0")
    if [ "$STILL_THERE" -le 0 ]; then
      echo "All clusters deleted."
      break
    fi
    echo "Waiting... ($STILL_THERE clusters remaining)"
    sleep 30
  done
fi

# 3. Clean up Networking resources
echo "Cleaning up orphaned Networking resources..."

# Firewalls
FIREWALLS=$(gcloud compute firewall-rules list --project=$PROJECT --format="value(name)" | grep -E "latest-gke-features-|enterprise-gke-|basic-gke-" | grep -v -E "repo-agent-standard|krmapihost-kcc-instance|kcc-dash-dont-delete" || true)
for F in $FIREWALLS; do
  echo "Deleting firewall: $F"
  gcloud compute firewall-rules delete $F --project=$PROJECT --quiet || true
done

# Routers and NATs across all regions
REGIONS=$(gcloud compute regions list --project=$PROJECT --format="value(name)")
for RGN in $REGIONS; do
  ROUTERS=$(gcloud compute routers list --project=$PROJECT --regions=$RGN --format="value(name)" | grep -E "latest-gke-features-|enterprise-gke-|basic-gke-" | grep -v -E "repo-agent-standard|krmapihost-kcc-instance|kcc-dash-dont-delete" || true)
  for R in $ROUTERS; do
    echo "Checking NATs for router $R in $RGN"
    NATS=$(gcloud compute routers describe $R --project=$PROJECT --region=$RGN --format="value(nats.name)" | tr ';' ' ')
    if [ -n "$NATS" ]; then
      for NAT in $NATS; do
        echo "Deleting NAT $NAT from router $R"
        gcloud compute routers nats delete $NAT --router=$R --region=$RGN --project=$PROJECT --quiet || true
      done
    fi
    echo "Deleting router $R"
    gcloud compute routers delete $R --region=$RGN --project=$PROJECT --quiet || true
  done
done

echo "Waiting for routers to be fully deleted..."
for i in {1..10}; do
  STILL_THERE=$(gcloud compute routers list --project=$PROJECT --format="value(name)" | grep -E "latest-gke-features-|enterprise-gke-|basic-gke-" | grep -v -E "repo-agent-standard|krmapihost-kcc-instance|kcc-dash-dont-delete" | wc -l)
  if [ "$STILL_THERE" -le 0 ]; then
    echo "All targeted routers deleted."
    break
  fi
  echo "Waiting for routers... ($STILL_THERE remaining)"
  sleep 15
done

# VPN Resources
for RGN in $REGIONS; do
  TUNNELS=$(gcloud compute vpn-tunnels list --project=$PROJECT --regions=$RGN --format="value(name)" | grep -E "latest-gke-features-|enterprise-gke-|basic-gke-" | grep -v -E "repo-agent-standard|krmapihost-kcc-instance|kcc-dash-dont-delete" || true)
  for T in $TUNNELS; do
    echo "Deleting VPN tunnel: $T in $RGN"
    gcloud compute vpn-tunnels delete $T --region=$RGN --project=$PROJECT --quiet || true
  done
  
  VPNS=$(gcloud compute vpn-gateways list --project=$PROJECT --regions=$RGN --format="value(name)" | grep -E "latest-gke-features-|enterprise-gke-|basic-gke-" | grep -v -E "repo-agent-standard|krmapihost-kcc-instance|kcc-dash-dont-delete" || true)
  for V in $VPNS; do
    echo "Deleting VPN gateway: $V in $RGN"
    gcloud compute vpn-gateways delete $V --region=$RGN --project=$PROJECT --quiet || true
  done
done

# L7 Resources
FRULES=$(gcloud compute forwarding-rules list --project=$PROJECT --format="value(name)" | grep -E "latest-gke-features-|enterprise-gke-|basic-gke-" | grep -v -E "repo-agent-standard|krmapihost-kcc-instance|kcc-dash-dont-delete" || true)
for FR in $FRULES; do
  echo "Deleting forwarding rule: $FR"
  gcloud compute forwarding-rules delete $FR --project=$PROJECT --global --quiet 2>/dev/null || \
  gcloud compute forwarding-rules delete $FR --project=$PROJECT --region=$RGN --quiet || true
done

# Subnets
for RGN in $REGIONS; do
  SUBNETS=$(gcloud compute networks subnets list --project=$PROJECT --regions=$RGN --format="value(name)" | grep -E "latest-gke-features-|enterprise-gke-|basic-gke-" | grep -v -E "repo-agent-standard|krmapihost-kcc-instance|kcc-dash-dont-delete" || true)
  for S in $SUBNETS; do
    echo "Deleting subnet $S in $RGN"
    gcloud compute networks subnets delete $S --region=$RGN --project=$PROJECT --quiet || true
  done
done

# Networks (VPCs)
NETWORKS=$(gcloud compute networks list --project=$PROJECT --format="value(name)" | grep -E "latest-gke-features-|enterprise-gke-|basic-gke-" | grep -v -E "repo-agent-standard|krmapihost-kcc-instance|kcc-dash-dont-delete" || true)
for N in $NETWORKS; do
  echo "Deleting network $N"
  gcloud compute networks delete $N --project=$PROJECT --quiet || true
done

echo "=== Cleanup Complete ==="
