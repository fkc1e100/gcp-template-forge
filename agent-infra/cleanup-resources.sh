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

# 0. Quota Check (Before)
echo "Capturing Quota Status before cleanup..."
gcloud compute project-info describe --project="$PROJECT" --format="json" > /tmp/quota_before.json || true

echo "Current Quota Status (Before Cleanup):"
python3 -c "import sys, json; data = json.load(open('/tmp/quota_before.json')); print(f\"{'Metric':<40} {'Usage':<10} {'Limit':<10}\"); print('-'*60); [print(f\"{q.get('metric','N/A'):<40} {q.get('usage',0):<10.1f} {q.get('limit',0):<10.1f}\") for q in data.get('quotas', []) if q.get('usage', 0) > 0]" || true
python3 -c "
import json, sys
try:
    data = json.load(open('/tmp/quota_before.json'))
    quotas = {q['metric']: q for q in data.get('quotas', [])}
    
    # Define critical metrics and the minimum available capacity we want to guarantee
    checks = {
        'CPUS': 10.0,
        'NETWORKS': 1.0,
        'FIREWALLS': 5.0,
        'ROUTERS': 2.0
    }
    
    need_cleanup = False
    for metric, min_available in checks.items():
        q = quotas.get(metric)
        if q:
            available = q['limit'] - q['usage']
            print(f'Metric {metric}: Usage={q[\"usage\"]}, Limit={q[\"limit\"]}, Available={available}')
            if available < min_available:
                print(f'  -> Critical: Need at least {min_available} available!')
                need_cleanup = True
        else:
            # If metric not found, assume it's fine or not applicable
            pass
            
    if not need_cleanup:
        print('All critical quotas have sufficient space. Skipping cleanup.')
        sys.exit(100)
    else:
        print('Some quotas are near limits. Proceeding with cleanup.')
        
except Exception as e:
    print(f'Error checking quotas: {e}. Proceeding with cleanup as fallback.')
"

if [ $? -eq 100 ]; then
  echo "=== Skipping Cleanup (Sufficient Quota) ==="
  exit 0
fi

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
gcloud container clusters get-credentials "$KCC_CLUSTER" --region "$REGION" --project "$PROJECT" 2>/dev/null || echo "Failed to get KCC credentials, skipping KCC cleanup"

if kubectl cluster-info &>/dev/null; then
  echo "Deleting all KCC-managed resources for orphaned environments..."
  KCC_TYPES="containercluster,computenetwork,computevpc,computesubnetwork,computerouter,computerouternat,computefirewall,storagebucket"
TARGET_PATTERN="latest-gke-features-|enterprise-gke-|basic-gke-|gke-kuberay-kueue-multitenant-|gke-ray-mt-|gke-inf-fuse-cache-|gke-inference-fuse-|gke-ai-inference-|gke-llm-inference-|gke-vllm-staging-|gke-basic-|latest-features-|gke-fqdn-egress-security-|gke-topology-aware-routing-|gke-inference-tf-"
IGNORE_PATTERN="repo-agent-standard|krmapihost-kcc-instance|kcc-dash-dont-delete|gke-gca-2025-forge-tf-state"
CLUSTER_FILTER="(resourceLabels.project=gcp-template-forge OR name ~ latest-gke-features- OR name ~ enterprise-gke- OR name ~ basic-gke- OR name ~ gke- OR name ~ gke-topology-aware-routing-) AND name != \$KCC_CLUSTER"

  KCC_RESOURCES=$(kubectl get "$KCC_TYPES" -n "$KCC_NAMESPACE" -o name | grep -E "$TARGET_PATTERN" | grep -v -E "$IGNORE_PATTERN" || true)
  
  echo "$KCC_RESOURCES" | while read -r RES; do
    [ -z "$RES" ] && continue
    # Try to get the 'template' label value for more robust active resource detection
    T_LABEL=$(kubectl get "$RES" -n "$KCC_NAMESPACE" -o jsonpath='{.metadata.labels.template}' 2>/dev/null || true)
    SKIP=false
    while read -r RUN_ID; do
      [ -z "$RUN_ID" ] && continue
      SUFFIX="${RUN_ID: -6}"
      if [[ "$RES" == *"$RUN_ID"* ]] || [[ "$RES" == *"$SUFFIX"* ]] || [[ "$T_LABEL" == *"$SUFFIX"* ]]; then
        echo "Skipping active resource (name: $RES, template_label: $T_LABEL)"
        SKIP=true
        break
      fi
    done <<< "$(echo "$ALL_ACTIVE" | tr ' ' '\n')"
    if [ "$SKIP" = false ]; then
      echo "Deleting orphaned KCC resource: $RES"
      kubectl delete "$RES" -n "$KCC_NAMESPACE" --wait=false || true
    fi
  done
fi

# 2. Clean up GKE Clusters (Terraform)
echo "Searching for orphaned Terraform clusters..."
TF_CLUSTERS=$(gcloud container clusters list \
  --project="$PROJECT" \
  --filter="$CLUSTER_FILTER" \
  --format="value(name, zone.scope(), resourceLabels.template)")

DELETED_CLUSTERS=false
while read -r CLUSTER C_LOC T_LABEL; do
  [ -z "$CLUSTER" ] && continue
  
  SKIP=false
  while read -r RUN_ID; do
    [ -z "$RUN_ID" ] && continue
    SUFFIX="${RUN_ID: -6}"
    if [[ "$CLUSTER" == *"$RUN_ID"* ]] || [[ "$CLUSTER" == *"$SUFFIX"* ]] || [[ "$T_LABEL" == *"$SUFFIX"* ]]; then
      echo "Skipping active cluster (name: $CLUSTER, template_label: $T_LABEL)"
      SKIP=true
      break
    fi
  done <<< "$(echo "$ALL_ACTIVE" | tr ' ' '\n')"
  
  if [ "$SKIP" = false ]; then
    STATUS=$(gcloud container clusters describe "$CLUSTER" --location="$C_LOC" --project="$PROJECT" --format="value(status)" 2>/dev/null || echo "UNKNOWN")
    if [ "$STATUS" = "PROVISIONING" ]; then
      echo "Cluster $CLUSTER is still PROVISIONING. Skipping it for now to let it finish."
      continue
    fi

    echo "Deleting orphaned TF cluster: $CLUSTER in $C_LOC"
    gcloud beta container clusters update "$CLUSTER" --location="$C_LOC" --project="$PROJECT" --no-deletion-protection --quiet &>/dev/null || true
    gcloud container clusters delete "$CLUSTER" --location="$C_LOC" --project="$PROJECT" --quiet --async || true
    DELETED_CLUSTERS=true
  fi
done <<< "$TF_CLUSTERS"

if [ "$DELETED_CLUSTERS" = true ]; then
  echo "Waiting for clusters to be deleted (up to 10 minutes)..."
  i=1
  while [ "$i" -le 20 ]; do
    STILL_THERE=$(gcloud container clusters list --project="$PROJECT" --filter="$CLUSTER_FILTER" --format="value(name)" 2>/dev/null | wc -l || echo "0")
    if [ "$STILL_THERE" -le 0 ]; then
      echo "All clusters deleted."
      break
    fi
    echo "Waiting... ($STILL_THERE clusters remaining)"
    sleep 30
    i=$((i + 1))
  done
fi

# 3. Clean up Networking resources
echo "Cleaning up orphaned Networking resources..."

# Firewalls
FIREWALLS=$(gcloud compute firewall-rules list --project="$PROJECT" --format="value(name)" | grep -E "$TARGET_PATTERN" | grep -v -E "$IGNORE_PATTERN" || true)
echo "$FIREWALLS" | while read -r F; do
  [ -z "$F" ] && continue
  echo "Deleting firewall: $F"
  gcloud compute firewall-rules delete "$F" --project="$PROJECT" --quiet || true
done

# 4. Clean up GCS Buckets (non-KCC)
echo "Searching for orphaned GCS buckets..."
# Match common patterns used by templates for both TF and KCC paths
BUCKETS=$(gcloud storage buckets list --project="$PROJECT" --format="value(name)" | grep -E "$TARGET_PATTERN" | grep -v -E "$IGNORE_PATTERN" || true)

echo "$BUCKETS" | while read -r B; do
  [ -z "$B" ] && continue
  SKIP=false
  while read -r RUN_ID; do
    [ -z "$RUN_ID" ] && continue
    SUFFIX="${RUN_ID: -6}"
    if [[ "$B" == *"$RUN_ID"* ]] || [[ "$B" == *"$SUFFIX"* ]]; then
      echo "Skipping active bucket: $B"
      SKIP=true
      break
    fi
  done <<< "$(echo "$ALL_ACTIVE" | tr ' ' '\n')"
  
  if [ "$SKIP" = false ]; then
    echo "Deleting orphaned bucket: $B"
    gcloud storage buckets delete gs://"$B" --project="$PROJECT" --quiet || true
  fi
done

# 5. Clean up Routers and NATs across all regions
REGIONS=$(gcloud compute regions list --project="$PROJECT" --format="value(name)")
echo "$REGIONS" | while read -r RGN; do
  [ -z "$RGN" ] && continue
  ROUTERS=$(gcloud compute routers list --project="$PROJECT" --regions="$RGN" --format="value(name)" | grep -E "$TARGET_PATTERN" | grep -v -E "$IGNORE_PATTERN" || true)
  echo "$ROUTERS" | while read -r R; do
    [ -z "$R" ] && continue
    echo "Checking NATs for router $R in $RGN"
    NATS=$(gcloud compute routers describe "$R" --project="$PROJECT" --region="$RGN" --format="value(nats.name)" | tr ';' ' ')
    if [ -n "$NATS" ]; then
      echo "$NATS" | tr ' ' '\n' | while read -r NAT; do
        [ -z "$NAT" ] && continue
        echo "Deleting NAT $NAT from router $R"
        gcloud compute routers nats delete "$NAT" --router="$R" --region="$RGN" --project="$PROJECT" --quiet || true
      done
    fi
    echo "Deleting router $R"
    gcloud compute routers delete "$R" --region="$RGN" --project="$PROJECT" --quiet || true
  done
done

echo "Waiting for routers to be fully deleted..."
i=1
while [ "$i" -le 10 ]; do
  STILL_THERE=$(gcloud compute routers list --project="$PROJECT" --format="value(name)" | grep -E "$TARGET_PATTERN" | grep -v -E "$IGNORE_PATTERN" | wc -l)
  if [ "$STILL_THERE" -le 0 ]; then
    echo "All targeted routers deleted."
    break
  fi
  echo "Waiting for routers... ($STILL_THERE remaining)"
  sleep 15
  i=$((i + 1))
done

# VPN Resources
echo "$REGIONS" | while read -r RGN; do
  [ -z "$RGN" ] && continue
  TUNNELS=$(gcloud compute vpn-tunnels list --project="$PROJECT" --regions="$RGN" --format="value(name)" | grep -E "$TARGET_PATTERN" | grep -v -E "$IGNORE_PATTERN" || true)
  echo "$TUNNELS" | while read -r T; do
    [ -z "$T" ] && continue
    echo "Deleting VPN tunnel: $T in $RGN"
    gcloud compute vpn-tunnels delete "$T" --region="$RGN" --project="$PROJECT" --quiet || true
  done
  
  VPNS=$(gcloud compute vpn-gateways list --project="$PROJECT" --regions="$RGN" --format="value(name)" | grep -E "$TARGET_PATTERN" | grep -v -E "$IGNORE_PATTERN" || true)
  echo "$VPNS" | while read -r V; do
    [ -z "$V" ] && continue
    echo "Deleting VPN gateway: $V in $RGN"
    gcloud compute vpn-gateways delete "$V" --region="$RGN" --project="$PROJECT" --quiet || true
  done
done

# L7 Resources
FRULES=$(gcloud compute forwarding-rules list --project="$PROJECT" --format="value(name)" | grep -E "$TARGET_PATTERN" | grep -v -E "$IGNORE_PATTERN" || true)
echo "$FRULES" | while read -r FR; do
  [ -z "$FR" ] && continue
  echo "Deleting forwarding rule: $FR"
  gcloud compute forwarding-rules delete "$FR" --project="$PROJECT" --global --quiet 2>/dev/null || \
  gcloud compute forwarding-rules delete "$FR" --project="$PROJECT" --region="$REGION" --quiet || true
done

# Subnets
echo "$REGIONS" | while read -r RGN; do
  [ -z "$RGN" ] && continue
  SUBNETS=$(gcloud compute networks subnets list --project="$PROJECT" --regions="$RGN" --format="value(name)" | grep -E "$TARGET_PATTERN" | grep -v -E "$IGNORE_PATTERN" || true)
  echo "$SUBNETS" | while read -r S; do
    [ -z "$S" ] && continue
    echo "Deleting subnet $S in $RGN"
    gcloud compute networks subnets delete "$S" --region="$RGN" --project="$PROJECT" --quiet || true
  done
done

# Networks (VPCs)
NETWORKS=$(gcloud compute networks list --project="$PROJECT" --format="value(name)" | grep -E "$TARGET_PATTERN" | grep -v -E "$IGNORE_PATTERN" || true)
echo "$NETWORKS" | while read -r N; do
  [ -z "$N" ] && continue
  echo "Initiating deletion of network $N..."
  gcloud compute networks delete "$N" --project="$PROJECT" --quiet || true
done

echo "Waiting for networks to be fully deleted..."
i=1
while [ "$i" -le 15 ]; do
  STILL_THERE=$(gcloud compute networks list --project="$PROJECT" --format="value(name)" | grep -E "$TARGET_PATTERN" | grep -v -E "$IGNORE_PATTERN" | wc -l)
  if [ "$STILL_THERE" -le 0 ]; then
    echo "All targeted networks deleted."
    break
  fi
  echo "Waiting for $STILL_THERE networks to delete... ($i/15)"
  sleep 20
  i=$((i + 1))
done

# 4. Quota Check (After) and Comparison
echo "Capturing Quota Status after cleanup..."
gcloud compute project-info describe --project="$PROJECT" --format="json" > /tmp/quota_after.json || true

echo "Quota Comparison (Before vs After):"
python3 << 'EOF' || true
import sys, json, os
try:
    if not os.path.exists('/tmp/quota_before.json') or os.path.getsize('/tmp/quota_before.json') == 0:
        raise ValueError('quota_before.json is missing or empty')
    if not os.path.exists('/tmp/quota_after.json') or os.path.getsize('/tmp/quota_after.json') == 0:
        raise ValueError('quota_after.json is missing or empty')
    
    before = json.load(open('/tmp/quota_before.json'))
    after = json.load(open('/tmp/quota_after.json'))
except Exception as e:
    print(f'Note: Could not compare quotas (this is normal if gcloud failed): {e}')
    sys.exit(0)

before_quotas = {q['metric']: q for q in before.get('quotas', [])}
after_quotas = {q['metric']: q for q in after.get('quotas', [])}

all_metrics = set(before_quotas.keys()).union(set(after_quotas.keys()))

print(f"{'Metric':<40} {'Before':<10} {'After':<10} {'Diff':<10} {'Limit':<10}")
print('-' * 80)

for metric in sorted(all_metrics):
    b = before_quotas.get(metric, {})
    a = after_quotas.get(metric, {})
    
    b_usage = b.get('usage', 0.0)
    a_usage = a.get('usage', 0.0)
    limit = b.get('limit', 0.0) or a.get('limit', 0.0)
    
    diff = a_usage - b_usage
    
    if b_usage > 0 or a_usage > 0 or diff != 0:
        print(f"{metric:<40} {b_usage:<10.1f} {a_usage:<10.1f} {diff:<10.1f} {limit:<10.1f}")
EOF

echo "=== Cleanup Complete ==="
