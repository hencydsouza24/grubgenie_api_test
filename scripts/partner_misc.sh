#!/usr/bin/env bash
# Partner misc reads: active order by table, WhatsApp agent settings + audience segments, and
# the front-desk report (with optional XLSX export).
# Usage: bash partner_misc.sh active-order <tableId>
#        bash partner_misc.sh agent-settings get
#        bash partner_misc.sh agent-settings update <field> <value>
#        bash partner_misc.sh audience-segments
#        bash partner_misc.sh front-desk-report [--export] <from> <to> [scope] [branchId]
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"
source "$GG_LIB_DIR/api_partner_misc.sh"

CMD="${1:-}"
gg_require "$CMD" "Usage: partner_misc.sh active-order|agent-settings|audience-segments|front-desk-report [args]"
shift

case "$CMD" in
  active-order)
    TABLE_ID="${1:-}"
    gg_require "$TABLE_ID" "Usage: partner_misc.sh active-order <tableId>"
    gg_order_active_by_table "$TABLE_ID"
    ;;

  agent-settings)
    SUB="${1:-get}"
    case "$SUB" in
      get)
        gg_whatsapp_agent_settings_get
        ;;
      update)
        FIELD="${2:-}"
        VALUE="${3:-}"
        gg_require "$FIELD" "Usage: partner_misc.sh agent-settings update <field> <value>"
        gg_whatsapp_agent_settings_update "$FIELD" "$VALUE"
        ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: partner_misc.sh agent-settings get|update [args]" ;;
    esac
    ;;

  audience-segments)
    gg_whatsapp_audience_segments
    ;;

  front-desk-report)
    EXPORT=0
    if [ "${1:-}" = "--export" ]; then
      EXPORT=1
      shift
    fi
    FROM="${1:-}"
    TO="${2:-}"
    SCOPE="${3:-single}"
    BRANCH_ID="${4:-}"
    gg_require "$FROM" "Usage: partner_misc.sh front-desk-report [--export] <from> <to> [scope] [branchId]"
    gg_require "$TO" "Usage: partner_misc.sh front-desk-report [--export] <from> <to> [scope] [branchId]"
    if [ "$EXPORT" -eq 1 ]; then
      OUT_FILE="front-desk-report-${FROM}-to-${TO}.xlsx"
      gg_front_desk_report_export "$FROM" "$TO" "$SCOPE" "$BRANCH_ID" > "$OUT_FILE"
      gg_info "Saved: $OUT_FILE"
    else
      gg_front_desk_report "$FROM" "$TO" "$SCOPE" "$BRANCH_ID"
    fi
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "Unknown command: $CMD (expected active-order|agent-settings|audience-segments|front-desk-report)"
    ;;
esac
