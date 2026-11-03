#!/usr/bin/env bash
# Partner CRM — Guest sub-resources, Inquiry, Insights. All routes use partner bearer auth.
#
# Usage: bash crm.sh guest whatsapp-thread <guestId> [limit] [before]
#        bash crm.sh guest campaigns <guestId>
#        bash crm.sh guest inquiries <guestId>
#        bash crm.sh guest calls <guestId>
#        bash crm.sh guest engagement-summary <guestId>
#        bash crm.sh inquiry list [k=v ...]
#        bash crm.sh inquiry create <guestName> <guestPhone> <inquiryType> [summary]
#        bash crm.sh inquiry get <inquiryId>
#        bash crm.sh inquiry update <inquiryId> [guestName] [guestPhone] [inquiryType] [summary]
#        bash crm.sh inquiry delete <inquiryId>
#        bash crm.sh inquiry status <inquiryId> <status> [reservationId]
#        bash crm.sh insights order-graph-data [fromDate] [toDate]
#        bash crm.sh insights menu-performance-details [fromDate] [toDate]
#        bash crm.sh insights category-rollup [fromDate] [toDate]
#        bash crm.sh insights weekly <branchId>
#        bash crm.sh insights promote-dish <itemId>
#        bash crm.sh insights hourly-demand <branchId> [fromDate] [toDate]
#
# Pass "" for an optional positional field you want to skip while still setting a later one, e.g.
# `inquiry update <id> "" "" dining`. menu-performance-details and category-rollup responses are
# NOT wrapped in `.result` — see the NOTE in lib/api_partner_crm.sh.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

GROUP="${1:-}"
gg_require "$GROUP" "Usage: crm.sh guest|inquiry|insights <subcommand> [args]"
SUB="${2:-}"

case "$GROUP" in
  guest)
    gg_require "$SUB" "Usage: crm.sh guest whatsapp-thread|campaigns|inquiries|calls|engagement-summary <guestId> [args]"
    GUEST_ID="${3:-}"
    gg_require "$GUEST_ID" "Usage: crm.sh guest $SUB <guestId> [args]"
    case "$SUB" in
      whatsapp-thread)    RESP="$(gg_guest_whatsapp_thread "$GUEST_ID" "${4:-}" "${5:-}")" || exit $? ;;
      campaigns)          RESP="$(gg_guest_campaigns "$GUEST_ID")" || exit $? ;;
      inquiries)          RESP="$(gg_guest_inquiries "$GUEST_ID")" || exit $? ;;
      calls)               RESP="$(gg_guest_calls "$GUEST_ID")" || exit $? ;;
      engagement-summary) RESP="$(gg_guest_engagement_summary "$GUEST_ID")" || exit $? ;;
      *) gg_die "$GG_EXIT_USAGE" "Unknown guest subcommand: $SUB" ;;
    esac
    echo "$RESP" | jq '.result'
    ;;

  inquiry)
    gg_require "$SUB" "Usage: crm.sh inquiry list|create|get|update|delete|status [args]"
    case "$SUB" in
      list)
        RESP="$(gg_inquiry_list "${@:3}")" || exit $?
        echo "$RESP" | jq '.result'
        ;;
      create)
        GUEST_NAME="${3:-}"
        GUEST_PHONE="${4:-}"
        INQUIRY_TYPE="${5:-}"
        gg_require "$GUEST_NAME" "Usage: crm.sh inquiry create <guestName> <guestPhone> <inquiryType> [summary]"
        RESP="$(gg_inquiry_create "$GUEST_NAME" "$GUEST_PHONE" "$INQUIRY_TYPE" "${6:-}")" || exit $?
        echo "$RESP" | jq '.result'
        ;;
      get)
        INQUIRY_ID="${3:-}"
        gg_require "$INQUIRY_ID" "Usage: crm.sh inquiry get <inquiryId>"
        RESP="$(gg_inquiry_get "$INQUIRY_ID")" || exit $?
        echo "$RESP" | jq '.result'
        ;;
      update)
        INQUIRY_ID="${3:-}"
        gg_require "$INQUIRY_ID" "Usage: crm.sh inquiry update <inquiryId> [guestName] [guestPhone] [inquiryType] [summary]"
        RESP="$(gg_inquiry_update "$INQUIRY_ID" "${4:-}" "${5:-}" "${6:-}" "${7:-}")" || exit $?
        echo "$RESP" | jq '.result'
        ;;
      delete)
        INQUIRY_ID="${3:-}"
        gg_require "$INQUIRY_ID" "Usage: crm.sh inquiry delete <inquiryId>"
        gg_inquiry_delete "$INQUIRY_ID" >/dev/null || exit $?
        gg_info "Inquiry $INQUIRY_ID deleted"
        ;;
      status)
        INQUIRY_ID="${3:-}"
        STATUS="${4:-}"
        gg_require "$INQUIRY_ID" "Usage: crm.sh inquiry status <inquiryId> <status> [reservationId]"
        gg_require "$STATUS" "Usage: crm.sh inquiry status <inquiryId> <status> [reservationId]"
        RESP="$(gg_inquiry_set_status "$INQUIRY_ID" "$STATUS" "${5:-}")" || exit $?
        echo "$RESP" | jq '.result'
        ;;
      *) gg_die "$GG_EXIT_USAGE" "Unknown inquiry subcommand: $SUB" ;;
    esac
    ;;

  insights)
    gg_require "$SUB" "Usage: crm.sh insights order-graph-data|menu-performance-details|category-rollup|weekly|promote-dish|hourly-demand [args]"
    case "$SUB" in
      order-graph-data)
        RESP="$(gg_insights_order_graph_data "${3:-}" "${4:-}")" || exit $?
        echo "$RESP" | jq '.result'
        ;;
      menu-performance-details)
        # NOT wrapped in `.result` — see the NOTE in lib/api_partner_crm.sh.
        RESP="$(gg_insights_menu_performance_details "${3:-}" "${4:-}")" || exit $?
        echo "$RESP" | jq '.data'
        ;;
      category-rollup)
        # NOT wrapped in `.result` — see the NOTE in lib/api_partner_crm.sh.
        RESP="$(gg_insights_category_rollup "${3:-}" "${4:-}")" || exit $?
        echo "$RESP" | jq '.data'
        ;;
      weekly)
        BRANCH_ID="${3:-}"
        gg_require "$BRANCH_ID" "Usage: crm.sh insights weekly <branchId>"
        RESP="$(gg_insights_weekly "$BRANCH_ID")" || exit $?
        echo "$RESP" | jq '.result'
        ;;
      promote-dish)
        ITEM_ID="${3:-}"
        gg_require "$ITEM_ID" "Usage: crm.sh insights promote-dish <itemId>"
        RESP="$(gg_insights_promote_dish "$ITEM_ID")" || exit $?
        echo "$RESP" | jq '.result'
        ;;
      hourly-demand)
        BRANCH_ID="${3:-}"
        gg_require "$BRANCH_ID" "Usage: crm.sh insights hourly-demand <branchId> [fromDate] [toDate]"
        RESP="$(gg_insights_hourly_demand "$BRANCH_ID" "${4:-}" "${5:-}")" || exit $?
        echo "$RESP" | jq '.result'
        ;;
      *) gg_die "$GG_EXIT_USAGE" "Unknown insights subcommand: $SUB" ;;
    esac
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "Unknown group: $GROUP (expected guest|inquiry|insights)"
    ;;
esac
