#!/usr/bin/env bash
# patch-overseer-iterate-labels.sh
#
# Fixes the known defect where Overseer iterate SandboxTasks are missing the
# `review.gemini.google.com/repowatch: gcp-template-forge` label, causing them
# to never be dispatched by the repowatch-controller.
#
# WHEN TO RUN:
#   After any CI failure where the Overseer logs "infrastructure stall" but no
#   new sandbox appears in the fkc1e100 namespace. Run this script to patch all
#   pending iterate tasks and force dispatch.
#
# USAGE:
#   # Dry-run (shows what would be patched):
#   ./agent-infra/patch-overseer-iterate-labels.sh --dry-run
#
#   # Apply patches:
#   ./agent-infra/patch-overseer-iterate-labels.sh
#
# CONTEXT: This connects to the repo-agent-standard GKE cluster.
# Ensure kubectl context is set to: gke_gca-gke-2025_us-central1_repo-agent-standard

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[dry-run] No changes will be applied."
fi

REPOWATCH_LABEL="review.gemini.google.com/repowatch"
REPOWATCH_VALUE="gcp-template-forge"
NAMESPACES=("fkc1e100" "overseer-gcp-template-forge")

echo "=== Patching iterate SandboxTasks missing repowatch label ==="
echo "Target namespaces: ${NAMESPACES[*]}"
echo ""

PATCHED=0
SKIPPED=0

for NS in "${NAMESPACES[@]}"; do
  echo "--- Namespace: $NS ---"

  # Get all SandboxTasks that have "iterate" in their name (Overseer heal tasks)
  TASKS=$(kubectl get sandboxtask -n "$NS" \
    --no-headers -o custom-columns='NAME:.metadata.name' 2>/dev/null \
    | grep -i "iterate" || true)

  if [ -z "$TASKS" ]; then
    echo "  No iterate SandboxTasks found."
    continue
  fi

  while IFS= read -r TASK; do
    [ -z "$TASK" ] && continue

    # Check if it already has the repowatch label
    CURRENT_LABEL=$(kubectl get sandboxtask "$TASK" -n "$NS" \
      -o jsonpath="{.metadata.labels.${REPOWATCH_LABEL//\./\\.}}" 2>/dev/null || echo "")

    if [ "$CURRENT_LABEL" = "$REPOWATCH_VALUE" ]; then
      echo "  SKIP $TASK — already has label"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi

    # Check task state — only patch pending/unstarted tasks
    TASK_STATE=$(kubectl get sandboxtask "$TASK" -n "$NS" \
      -o jsonpath='{.status.taskState}' 2>/dev/null || echo "")

    if [[ "$TASK_STATE" == "Completed" ]] || [[ "$TASK_STATE" == "Failed" ]]; then
      echo "  SKIP $TASK — already in terminal state ($TASK_STATE)"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi

    echo "  PATCH $TASK (state: ${TASK_STATE:-unset}) — adding $REPOWATCH_LABEL=$REPOWATCH_VALUE"

    if [ "$DRY_RUN" = false ]; then
      kubectl label sandboxtask "$TASK" -n "$NS" \
        "${REPOWATCH_LABEL}=${REPOWATCH_VALUE}" \
        --overwrite
      echo "  ✓ Patched"
      PATCHED=$((PATCHED + 1))
    else
      echo "  [dry-run] Would patch"
      PATCHED=$((PATCHED + 1))
    fi
  done <<< "$TASKS"
done

echo ""
echo "=== Summary ==="
echo "  Patched: $PATCHED"
echo "  Skipped: $SKIPPED"

if [ "$PATCHED" -gt 0 ] && [ "$DRY_RUN" = false ]; then
  echo ""
  echo "Patched tasks should now be picked up by repowatch-controller within 60 seconds."
  echo "Monitor with:"
  echo "  kubectl get sandboxtask -n fkc1e100 -w"
  echo "  kubectl get sandboxtask -n overseer-gcp-template-forge -w"
fi
