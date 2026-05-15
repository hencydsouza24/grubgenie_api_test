#!/bin/bash
# Trigger async POS menu sync job
# Usage: bash sync_pos_menu.sh [provider]  (default: petpooja)

SKILL=$(dirname "$0")
eval "$(bash $SKILL/auth.sh 2>/dev/null)"

PROVIDER="${1:-petpooja}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE/v1/partner/pos/sync-menu" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"provider\":\"$PROVIDER\"}")

BODY=$(echo "$RESPONSE" | head -n -1)
STATUS=$(echo "$RESPONSE" | tail -n1)

echo "Status: $STATUS"
echo "$BODY" | jq .

# 202 = job enqueued, check jobId
# 409 = sync already running
