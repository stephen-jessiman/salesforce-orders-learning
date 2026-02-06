#!/usr/bin/env bash
set -euo pipefail

TARGET_ORG="${1:-}"
ORG_ARGS=()

if [[ -n "${TARGET_ORG}" ]]; then
  ORG_ARGS+=(--target-org "${TARGET_ORG}")
fi

if ! command -v sf >/dev/null 2>&1; then
  echo "Error: Salesforce CLI (sf) is not installed."
  exit 1
fi

echo "Deploying project metadata..."
sf project deploy start "${ORG_ARGS[@]}"

echo "Assigning permission set Agentforce_Learning..."
if sf org assign permset --name Agentforce_Learning "${ORG_ARGS[@]}"; then
  echo "Permission set assigned."
else
  echo "Warning: Could not assign Agentforce_Learning. Continuing."
fi

echo "Seeding Agentforce learning data..."
sf apex run --file scripts/apex/seed_agentforce_data.apex "${ORG_ARGS[@]}"

echo "Initialization complete."
