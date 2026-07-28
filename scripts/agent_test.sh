#!/usr/bin/env bash
# Test the GrubGenie agent chat endpoint (unauthenticated — no session required).
# Usage: bash agent_test.sh "<message>" [dinerId]
# Default dinerId: 69f89034e0a784fea33a0d12 (existing test diner)
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

MESSAGE="${1:-}"
gg_require "$MESSAGE" 'Usage: agent_test.sh "<message>" [dinerId]'
DINER_ID="${2:-$GG_DINER_TEST}"

BODY="$(jq -n --arg message "$MESSAGE" '{message: $message}')" || exit $?
RESP="$(gg_http_or_die "agent chat" POST "/v1/test/agent-chat/${DINER_ID}" --json "$BODY")" || exit $?
echo "$RESP" | jq .
