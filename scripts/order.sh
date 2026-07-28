#!/usr/bin/env bash
# Order a menu item or combo into an existing cart, then place it.
# Usage: bash order.sh item <itemId> [qty]
#        bash order.sh combo [comboId] [qty]
# Requires: CART_ID (from create_cart.sh) — run `CART_ID=$(bash create_cart.sh)` first.
# Default comboId: 69f8757fd475a8cf66ed94f2 (Snack Combo, 24 AED)
# Prints: orderId of the placed order.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

TYPE="${1:-}"
gg_require "$TYPE" "Usage: order.sh item|combo <id> [qty]"
gg_require "${CART_ID:-}" "CART_ID not set — run: CART_ID=\$(bash create_cart.sh)"

case "$TYPE" in
  item)
    LINE_ID="${2:-}"
    gg_require "$LINE_ID" "Usage: order.sh item <itemId> [qty]"
    LINE_KEY=itemId
    ;;
  combo)
    LINE_ID="${2:-$GG_COMBO_SNACK}"
    LINE_KEY=comboId
    ;;
  *)
    gg_die "$GG_EXIT_USAGE" "Unknown order type: $TYPE (expected item|combo)"
    ;;
esac
QTY="${3:-1}"

ORDER_ID="$(gg_order_create "$CART_ID" "$LINE_KEY" "$LINE_ID" "$QTY")" || exit $?
PLACE_RESP="$(gg_order_place "$CART_ID" "$ORDER_ID")" || exit $?
PLACE_MSG="$(gg_json_field "$PLACE_RESP" '.message' "place message")" || exit $?
PLACE_STATUS="$(gg_json_field "$PLACE_RESP" '.status' "place status")" || exit $?
gg_info "Place result: $PLACE_MSG (status: $PLACE_STATUS)"

echo "$ORDER_ID"
