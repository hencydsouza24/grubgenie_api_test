#!/usr/bin/env bash
# Usage: eval "$(bash auth.sh)" [--force]
# Authenticates (idempotently — reuses a session younger than GG_SESSION_TTL seconds) and
# exports BASE, PARTNER_TOKEN, TABLE_ID, DINER_TOKEN, DINER_ID into the current shell.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

SESSION_PATH="$(gg_auth_ensure "$@")" || exit $?

echo "export BASE=$(jq -r '.base' "$SESSION_PATH")"
echo "export PARTNER_TOKEN=$(jq -r '.partnerToken' "$SESSION_PATH")"
echo "export TABLE_ID=$(jq -r '.tableId' "$SESSION_PATH")"
echo "export DINER_TOKEN=$(jq -r '.dinerToken' "$SESSION_PATH")"
echo "export DINER_ID=$(jq -r '.dinerId' "$SESSION_PATH")"
