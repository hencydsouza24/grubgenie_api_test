#!/usr/bin/env bash
# Order a combo and place it.
# Usage: bash order_combo.sh [comboId] [quantity]
# Requires: DINER_TOKEN, DINER_ID, CART_ID (from auth.sh + create_cart.sh)
# Default comboId: 69f8757fd475a8cf66ed94f2 (Snack Combo, 24 AED)
# Prints: ORDER_ID of the placed order

set -euo pipefail
BASE=${BASE:-http://localhost:3000}
COMBO_ID=${1:-69f8757fd475a8cf66ed94f2}
QTY=${2:-1}

ORDER_RESPONSE=$(curl -s -X POST "$BASE/v1/genie/order?cartId=$CART_ID&dinerId=$DINER_ID" \
  -H "Authorization: Bearer $DINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"items\":[{\"comboId\":\"$COMBO_ID\",\"quantity\":$QTY}]}")

ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.result.currentActiveOrder')

if [ "$ORDER_ID" = "null" ] || [ -z "$ORDER_ID" ]; then
  echo "Error creating combo order:" >&2
  echo "$ORDER_RESPONSE" | jq . >&2
  exit 1
fi

echo "# Combo order created: $ORDER_ID" >&2

# Place the order
PLACE=$(curl -s -X PUT "$BASE/v1/genie/order/place-order/$ORDER_ID?cartId=$CART_ID" \
  -H "Authorization: Bearer $DINER_TOKEN")
MSG=$(echo "$PLACE" | jq -r '.message')
echo "# Place result: $MSG" >&2

echo "$ORDER_ID"
