#!/usr/bin/env bash
# Order a menu item and place it.
# Usage: bash order_item.sh <itemId> [quantity]
# Requires: DINER_TOKEN, DINER_ID, CART_ID (from auth.sh + create_cart.sh)
# Prints: ORDER_ID of the placed order

set -euo pipefail
BASE=${BASE:-http://localhost:3000}
ITEM_ID=${1:?"Usage: order_item.sh <itemId> [quantity]"}
QTY=${2:-1}

ORDER_RESPONSE=$(curl -s -X POST "$BASE/v1/genie/order?cartId=$CART_ID&dinerId=$DINER_ID" \
  -H "Authorization: Bearer $DINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"items\":[{\"itemId\":\"$ITEM_ID\",\"quantity\":$QTY}]}")

ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.result.currentActiveOrder')

if [ "$ORDER_ID" = "null" ] || [ -z "$ORDER_ID" ]; then
  echo "Error creating order:" >&2
  echo "$ORDER_RESPONSE" | jq . >&2
  exit 1
fi

echo "# Order created: $ORDER_ID" >&2

# Place the order
PLACE=$(curl -s -X PUT "$BASE/v1/genie/order/place-order/$ORDER_ID?cartId=$CART_ID" \
  -H "Authorization: Bearer $DINER_TOKEN")
MSG=$(echo "$PLACE" | jq -r '.message')
echo "# Place result: $MSG" >&2

echo "$ORDER_ID"
