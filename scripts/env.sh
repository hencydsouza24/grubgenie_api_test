#!/usr/bin/env bash
# Usage: eval "$(bash env.sh [local|dev|prod])"
# Prints `export BASE=...` for the target environment — eval it, then run auth.sh.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

ENV_NAME="${1:-local}"
BASE_URL="$(gg_resolve_base "$ENV_NAME")" || exit $?

echo "export BASE=$BASE_URL"
gg_info "Environment: $ENV_NAME -> $BASE_URL"
