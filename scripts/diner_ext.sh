#!/usr/bin/env bash
# Diner-facing genie API extensions: combo fetching, order detail, profile identity linking.
# Usage: bash diner_ext.sh combo list
#        bash diner_ext.sh combo get <comboId>
#        bash diner_ext.sh order-detail <orderId>
#        bash diner_ext.sh link-identity <field> <value> <code>
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"
source "$GG_LIB_DIR/api_partner_misc.sh"

CMD="${1:-}"
gg_require "$CMD" "Usage: diner_ext.sh combo|order-detail|link-identity [args]"
shift

case "$CMD" in
  combo)
    SUB="${1:-}"
    gg_require "$SUB" "Usage: diner_ext.sh combo list|get <id>"
    case "$SUB" in
      list)
        gg_combo_list
        ;;
      get)
        COMBO_ID="${2:-}"
        gg_require "$COMBO_ID" "Usage: diner_ext.sh combo get <comboId>"
        gg_diner_combo_get "$COMBO_ID"
        ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: diner_ext.sh combo list|get <id>" ;;
    esac
    ;;

  order-detail)
    ORDER_ID="${1:-}"
    gg_require "$ORDER_ID" "Usage: diner_ext.sh order-detail <orderId>"
    gg_diner_order_detail "$ORDER_ID"
    ;;

  link-identity)
    FIELD="${1:-}"
    VALUE="${2:-}"
    CODE="${3:-}"
    gg_require "$FIELD" "Usage: diner_ext.sh link-identity <field> <value> <code>"
    gg_require "$VALUE" "Usage: diner_ext.sh link-identity <field> <value> <code>"
    gg_require "$CODE" "Usage: diner_ext.sh link-identity <field> <value> <code>"
    gg_diner_link_identity "$FIELD" "$VALUE" "$CODE"
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "Unknown command: $CMD (expected combo|order-detail|link-identity)"
    ;;
esac
