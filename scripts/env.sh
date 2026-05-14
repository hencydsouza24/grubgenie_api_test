#!/usr/bin/env bash
# Usage: eval "$(bash env.sh [local|dev|prod])"
# Sets BASE for the target environment, then run auth.sh.

ENV=${1:-local}

case "$ENV" in
  local) BASE="http://localhost:3000" ;;
  dev)   BASE="https://dev-backend.grubgenie.ai" ;;
  prod)  BASE="https://backend.grubgenie.ai" ;;
  *)
    echo "Unknown environment: $ENV" >&2
    echo "Usage: eval \"\$(bash env.sh [local|dev|prod])\"" >&2
    echo "  local  → http://localhost:3000" >&2
    echo "  dev    → https://dev-backend.grubgenie.ai" >&2
    echo "  prod   → https://backend.grubgenie.ai" >&2
    exit 1
    ;;
esac

echo "export BASE=$BASE"
echo "# Environment: $ENV → $BASE" >&2
