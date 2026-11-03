#!/usr/bin/env bash
# E2E staff-assisted ordering flow (partner-authenticated): a waiter/captain starts a cart at a
# table, adds an item, updates the order with one more unit of it, then places it. Fully
# self-contained — auths itself via the shared session (see auth.sh).
# Usage: bash staff_order.sh <tableId> <itemId> [qty]
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"
source "$GG_LIB_DIR/api_partner_misc.sh"

TABLE_ID="${1:-}"
ITEM_ID="${2:-}"
QTY="${3:-1}"
gg_require "$TABLE_ID" "Usage: staff_order.sh <tableId> <itemId> [qty]"
gg_require "$ITEM_ID" "Usage: staff_order.sh <tableId> <itemId> [qty]"

gg_step 1 "Start table cart (staff)"
CART_ID="$(gg_staff_cart_create "$TABLE_ID")" || exit $?
gg_kv "Cart" "$CART_ID"

gg_step 2 "Add item to cart (itemId=$ITEM_ID qty=$QTY)"
ORDER_ID="$(gg_staff_order_create "$CART_ID" itemId "$ITEM_ID" "$QTY")" || exit $?
gg_kv "Order" "$ORDER_ID"

gg_step 3 "Update order (add one more unit)"
UPDATE_RESP="$(gg_staff_order_update "$ORDER_ID" "$CART_ID" itemId "$ITEM_ID" 1)" || exit $?
gg_info "$(gg_json_message "$UPDATE_RESP")"

gg_step 4 "Place order"
PLACE_RESP="$(gg_staff_order_place "$ORDER_ID" "$CART_ID")" || exit $?
PLACE_MSG="$(gg_json_field "$PLACE_RESP" '.message' "place message")" || exit $?
PLACE_STATUS="$(gg_json_field "$PLACE_RESP" '.status' "place status")" || exit $?
gg_info "$PLACE_MSG (status: $PLACE_STATUS)"

gg_step "done" "Complete"
gg_info "Cart: $CART_ID | Order: $ORDER_ID"
