#!/usr/bin/env bash
# Full E2E dine-in + pay-in-person flow: auth -> cart -> order -> place -> (approve if needed)
# -> pay -> confirm. Fully self-contained — auths itself via the shared session (see auth.sh).
# Usage: bash flow_dine_in_pay.sh [itemId] [quantity]
# Default item: 691bf10018f1d3c34db1db00 (Ulli Vada, 12 AED)
# Handles manual orderAcceptanceMode: auto-accepts a pending order before payment.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

ITEM_ID="${1:-$GG_ITEM_ULLI_VADA}"
QTY="${2:-2}"

gg_step 1 "Create cart"
CART_ID="$(gg_cart_create)" || exit $?
gg_kv "Cart" "$CART_ID"

gg_step 2 "Create order (itemId=$ITEM_ID qty=$QTY)"
ORDER_ID="$(gg_order_create "$CART_ID" itemId "$ITEM_ID" "$QTY")" || exit $?
gg_kv "Order" "$ORDER_ID"

gg_step 3 "Place order"
PLACE_MSG="$(gg_order_place "$CART_ID" "$ORDER_ID")" || exit $?
gg_info "$PLACE_MSG"

gg_step 4 "Accept order if pending approval"
if echo "$PLACE_MSG" | grep -qi "approval"; then
  ACCEPT_MSG="$(gg_order_respond "$ORDER_ID" accept)" || exit $?
  gg_info "$ACCEPT_MSG"
else
  gg_info "No approval needed, skipping."
fi

gg_step 5 "Pay in person"
PAY_MSG="$(gg_pay_in_person "$CART_ID")" || exit $?
gg_info "$PAY_MSG"

gg_step 6 "Partner confirms payment"
CONFIRM_MSG="$(gg_payment_confirm "$CART_ID")" || exit $?
gg_info "$CONFIRM_MSG"

gg_step "done" "Complete"
gg_info "Cart: $CART_ID | Order: $ORDER_ID"
