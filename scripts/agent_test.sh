#!/usr/bin/env bash
# Test the GrubGenie agent chat endpoint.
# Usage: bash agent_test.sh "<message>" [dinerId]
# Default dinerId: 69f89034e0a784fea33a0d12 (existing test diner)

set -euo pipefail
BASE=${BASE:-http://localhost:3000}
MESSAGE=${1:?"Usage: agent_test.sh \"<message>\" [dinerId]"}
DINER_ID=${2:-69f89034e0a784fea33a0d12}

curl -s -X POST "$BASE/v1/test/agent-chat/$DINER_ID" \
  -H "Content-Type: application/json" \
  -d "{\"message\":$(echo "$MESSAGE" | jq -R .)}" | jq .
