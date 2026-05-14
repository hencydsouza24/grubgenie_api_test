#!/usr/bin/env bash
# Reset all tables to "available", force-clearing any active carts.
# Usage: bash reset_tables.sh
# Requires: PARTNER_TOKEN (from auth.sh)

set -euo pipefail
BASE=${BASE:-http://localhost:3000}

TABLE_IDS=$(curl -s "$BASE/v1/partner/table" \
  -H "Authorization: Bearer $PARTNER_TOKEN" | jq -r '.result[]._id')

for TID in $TABLE_IDS; do
  RESP=$(curl -s -X PUT "$BASE/v1/partner/table/table-status/$TID" \
    -H "Authorization: Bearer $PARTNER_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"status":"available","confirmed":true}')
  MSG=$(echo "$RESP" | jq -r '.message // tojson' 2>/dev/null)
  echo "# $TID -> $MSG" >&2
done

echo "# All tables reset to available" >&2
