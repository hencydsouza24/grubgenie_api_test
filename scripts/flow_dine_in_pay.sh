#!/usr/bin/env bash
# Full E2E dine-in + pay-in-person flow.
# Usage: bash flow_dine_in_pay.sh [itemId] [quantity]
# Default item: 691bf10018f1d3c34db1db00 (Ulli Vada, 12 AED)
# No env vars required — script handles all auth internally.
# Handles manual orderAcceptanceMode: auto-accepts pending order before payment.

set -euo pipefail
BASE=${BASE:-http://localhost:3000}
ITEM_ID=${1:-691bf10018f1d3c34db1db00}
QTY=${2:-2}

echo "=== Step 1: Partner auth ==="
PARTNER_TOKEN=$(curl -s -X POST "$BASE/v1/partner/auth/signin" \
  -H "Content-Type: application/json" \
  -d '{"email":"munch@yopmail.com","password":"Test@123"}' | jq -r '.result.accessToken')
echo "Partner token: ${PARTNER_TOKEN:0:20}..."

echo ""
echo "=== Step 2: Get table ==="
TABLE_ID=$(curl -s "$BASE/v1/partner/table" \
  -H "Authorization: Bearer $PARTNER_TOKEN" | jq -r '.result[0]._id')
echo "Table: $TABLE_ID"

echo ""
echo "=== Step 3: Diner auth ==="
DINER_RESPONSE=$(curl -s "$BASE/v1/genie/diner?customDomain=munch2&branchId=3XSJT&fingerprint=grubgenie-stripe-test-002")
DINER_TOKEN=$(echo "$DINER_RESPONSE" | jq -r '.result.accessToken')
DINER_ID=$(echo "$DINER_RESPONSE" | jq -r '.result._id')
echo "Diner: $DINER_ID"

echo ""
echo "=== Step 4: Create cart ==="
CART_RESPONSE=$(curl -s -X POST "$BASE/v1/genie/cart" \
  -H "Authorization: Bearer $DINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"tableId\":\"$TABLE_ID\"}")
CART_ID=$(echo "$CART_RESPONSE" | jq -r '.result.cartId')
echo "Cart: $CART_ID"

echo ""
echo "=== Step 5: Create order (itemId=$ITEM_ID qty=$QTY) ==="
ORDER_RESPONSE=$(curl -s -X POST "$BASE/v1/genie/order?cartId=$CART_ID&dinerId=$DINER_ID" \
  -H "Authorization: Bearer $DINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"items\":[{\"itemId\":\"$ITEM_ID\",\"quantity\":$QTY}]}")
ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.result.currentActiveOrder')
echo "Order: $ORDER_ID"

echo ""
echo "=== Step 6: Place order ==="
PLACE=$(curl -s -X PUT "$BASE/v1/genie/order/place-order/$ORDER_ID?cartId=$CART_ID" \
  -H "Authorization: Bearer $DINER_TOKEN")
PLACE_MSG=$(echo "$PLACE" | jq -r '.message')
echo "$PLACE_MSG"

echo ""
echo "=== Step 6b: Accept order if pending approval ==="
if echo "$PLACE_MSG" | grep -qi "approval"; then
  ACCEPT=$(curl -s -X PATCH "$BASE/v1/partner/order-history/respond/$ORDER_ID" \
    -H "Authorization: Bearer $PARTNER_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"action":"accept"}')
  echo "$(echo "$ACCEPT" | jq -r '.message')"
else
  echo "No approval needed, skipping."
fi

echo ""
echo "=== Step 7: Pay in person ==="
PAY=$(curl -s -X POST "$BASE/v1/genie/cart/$CART_ID/payment/pay-in-person" \
  -H "Authorization: Bearer $DINER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"dinerId\":\"$DINER_ID\"}")
echo "$(echo "$PAY" | jq -r '.message')"

echo ""
echo "=== Step 8: Partner confirms payment ==="
TODAY=$(date -u +%Y-%m-%d)
CONFIRM=$(curl -s -X PUT "$BASE/v1/partner/order-history/update-payment-status/$CART_ID" \
  -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"paymentStatus":"done","paymentMode":"cash","confirmed":true}')
echo "$(echo "$CONFIRM" | jq -r '.message')"

echo ""
echo "=== Done ==="
echo "Cart: $CART_ID | Order: $ORDER_ID | Diner: $DINER_ID"
