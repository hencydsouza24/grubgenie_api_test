#!/usr/bin/env bash
# Usage: CART_ID=$(bash create_cart.sh)
# Requires: DINER_TOKEN, TABLE_ID (from auth.sh)

set -euo pipefail
BASE=${BASE:-http://localhost:3000}

CART_RESPONSE=$(curl -s -X POST "$BASE/v1/genie/cart" \
  -H "Authorization: Bearer $DINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"tableId\":\"$TABLE_ID\"}")

CART_ID=$(echo "$CART_RESPONSE" | jq -r '.result.cartId')

if [ "$CART_ID" = "null" ] || [ -z "$CART_ID" ]; then
  echo "Error creating cart:" >&2
  echo "$CART_RESPONSE" | jq . >&2
  exit 1
fi

echo "# Cart: $CART_ID" >&2
echo "$CART_ID"
