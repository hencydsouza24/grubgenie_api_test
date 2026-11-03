#!/usr/bin/env bash
# Partner Ops — bundles three domains: AllOutlets (cross-branch rollup reads), Queue (walk-in
# queue CRUD + transitions), Role (custom partner roles, mounted at /v1/partner/roles — plural).
# Usage:
#   AllOutlets:
#     bash partner_ops.sh outlets
#     bash partner_ops.sh inquiries [key=value ...]
#     bash partner_ops.sh reservations [key=value ...]     # must include after=... before=...
#     bash partner_ops.sh queue-list [key=value ...]
#     bash partner_ops.sh notifications
#     bash partner_ops.sh notifications-read <branchId> <notificationId> [notificationId...]
#   Queue:
#     bash partner_ops.sh queue create <guestName> <guestPhone> <partySize> [quotedWaitMin] [preferenceNote]
#     bash partner_ops.sh queue list [key=value ...]
#     bash partner_ops.sh queue get <queueId>
#     bash partner_ops.sh queue update <queueId> [guestName] [guestPhone] [partySize] [quotedWaitMin] [preferenceNote]
#     bash partner_ops.sh queue delete <queueId>
#     bash partner_ops.sh queue notify <queueId>
#     bash partner_ops.sh queue table-ready <queueId> [tableId]
#     bash partner_ops.sh queue seat <queueId> [tableId]
#     bash partner_ops.sh queue abandon <queueId> [staff|converted]
#     bash partner_ops.sh queue reopen <queueId>
#   Role:
#     bash partner_ops.sh role permission-catalog [roleKey]
#     bash partner_ops.sh role list
#     bash partner_ops.sh role create <name> <permission> [permission...]
#     bash partner_ops.sh role update <roleId> <name-or-dash> [permission...]
#     bash partner_ops.sh role delete <roleId>
#
# `queue update`/`role update` use "-" as a skip sentinel for an omitted positional field — pass
# "-" to leave that field unchanged. [key=value ...] query args are passed straight through to
# gg_http's --query (see lib/api_partner_ops.sh).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

USAGE="Usage: partner_ops.sh outlets|inquiries|reservations|queue-list|notifications|notifications-read|queue <action>|role <action> [args]"

CMD="${1:-}"
gg_require "$CMD" "$USAGE"

case "$CMD" in
  # --- AllOutlets ---
  outlets)
    RESP="$(gg_all_outlets_list)" || exit $?
    echo "$RESP" | jq .
    ;;

  inquiries)
    shift
    RESP="$(gg_all_outlets_inquiries "$@")" || exit $?
    echo "$RESP" | jq .
    ;;

  reservations)
    shift
    RESP="$(gg_all_outlets_reservations "$@")" || exit $?
    echo "$RESP" | jq .
    ;;

  queue-list)
    shift
    RESP="$(gg_all_outlets_queue "$@")" || exit $?
    echo "$RESP" | jq .
    ;;

  notifications)
    RESP="$(gg_all_outlets_notifications)" || exit $?
    echo "$RESP" | jq .
    ;;

  notifications-read)
    BRANCH_ID="${2:-}"
    gg_require "$BRANCH_ID" "Usage: partner_ops.sh notifications-read <branchId> <notificationId> [notificationId...]"
    shift 2
    [ "$#" -ge 1 ] || gg_die "$GG_EXIT_USAGE" "Usage: partner_ops.sh notifications-read <branchId> <notificationId> [notificationId...]"
    gg_all_outlets_notifications_read "$BRANCH_ID" "$@"
    ;;

  # --- Queue ---
  queue)
    SUB="${2:-}"
    gg_require "$SUB" "Usage: partner_ops.sh queue create|list|get|update|delete|notify|table-ready|seat|abandon|reopen [args]"
    case "$SUB" in
      create)
        GUEST_NAME="${3:-}" GUEST_PHONE="${4:-}" PARTY_SIZE="${5:-}" QUOTED_WAIT_MIN="${6:-}" PREFERENCE_NOTE="${7:-}"
        gg_require "$GUEST_NAME" "Usage: partner_ops.sh queue create <guestName> <guestPhone> <partySize> [quotedWaitMin] [preferenceNote]"
        gg_require "$GUEST_PHONE" "Usage: partner_ops.sh queue create <guestName> <guestPhone> <partySize> [quotedWaitMin] [preferenceNote]"
        gg_require "$PARTY_SIZE" "Usage: partner_ops.sh queue create <guestName> <guestPhone> <partySize> [quotedWaitMin] [preferenceNote]"
        gg_queue_create "$GUEST_NAME" "$GUEST_PHONE" "$PARTY_SIZE" "$QUOTED_WAIT_MIN" "$PREFERENCE_NOTE"
        ;;
      list)
        shift 2
        RESP="$(gg_queue_list "$@")" || exit $?
        echo "$RESP" | jq .
        ;;
      get)
        QUEUE_ID="${3:-}"
        gg_require "$QUEUE_ID" "Usage: partner_ops.sh queue get <queueId>"
        RESP="$(gg_queue_get "$QUEUE_ID")" || exit $?
        echo "$RESP" | jq .
        ;;
      update)
        QUEUE_ID="${3:-}"
        gg_require "$QUEUE_ID" "Usage: partner_ops.sh queue update <queueId> [guestName] [guestPhone] [partySize] [quotedWaitMin] [preferenceNote]"
        RESP="$(gg_queue_update "$QUEUE_ID" "${4:--}" "${5:--}" "${6:--}" "${7:--}" "${8:--}")" || exit $?
        echo "$RESP" | jq .
        ;;
      delete)
        QUEUE_ID="${3:-}"
        gg_require "$QUEUE_ID" "Usage: partner_ops.sh queue delete <queueId>"
        gg_queue_delete "$QUEUE_ID"
        ;;
      notify)
        QUEUE_ID="${3:-}"
        gg_require "$QUEUE_ID" "Usage: partner_ops.sh queue notify <queueId>"
        gg_queue_notify "$QUEUE_ID"
        ;;
      table-ready)
        QUEUE_ID="${3:-}" TABLE_ID="${4:-}"
        gg_require "$QUEUE_ID" "Usage: partner_ops.sh queue table-ready <queueId> [tableId]"
        RESP="$(gg_queue_table_ready "$QUEUE_ID" "$TABLE_ID")" || exit $?
        echo "$RESP" | jq .
        ;;
      seat)
        QUEUE_ID="${3:-}" TABLE_ID="${4:-}"
        gg_require "$QUEUE_ID" "Usage: partner_ops.sh queue seat <queueId> [tableId]"
        RESP="$(gg_queue_seat "$QUEUE_ID" "$TABLE_ID")" || exit $?
        echo "$RESP" | jq .
        ;;
      abandon)
        QUEUE_ID="${3:-}" REASON="${4:-}"
        gg_require "$QUEUE_ID" "Usage: partner_ops.sh queue abandon <queueId> [staff|converted]"
        RESP="$(gg_queue_abandon "$QUEUE_ID" "$REASON")" || exit $?
        echo "$RESP" | jq .
        ;;
      reopen)
        QUEUE_ID="${3:-}"
        gg_require "$QUEUE_ID" "Usage: partner_ops.sh queue reopen <queueId>"
        gg_queue_reopen "$QUEUE_ID"
        ;;
      *)
        gg_die "$GG_EXIT_USAGE" "Unknown queue subcommand: $SUB"
        ;;
    esac
    ;;

  # --- Role ---
  role)
    SUB="${2:-}"
    gg_require "$SUB" "Usage: partner_ops.sh role permission-catalog|list|create|update|delete [args]"
    case "$SUB" in
      permission-catalog)
        ROLE_KEY="${3:-}"
        RESP="$(gg_role_permission_catalog "$ROLE_KEY")" || exit $?
        echo "$RESP" | jq .
        ;;
      list)
        RESP="$(gg_role_list)" || exit $?
        echo "$RESP" | jq .
        ;;
      create)
        NAME="${3:-}"
        gg_require "$NAME" "Usage: partner_ops.sh role create <name> <permission> [permission...]"
        shift 3
        [ "$#" -ge 1 ] || gg_die "$GG_EXIT_USAGE" "Usage: partner_ops.sh role create <name> <permission> [permission...]"
        RESP="$(gg_role_create "$NAME" "$@")" || exit $?
        echo "$RESP" | jq .
        ;;
      update)
        ROLE_ID="${3:-}" NAME="${4:--}"
        gg_require "$ROLE_ID" "Usage: partner_ops.sh role update <roleId> <name-or-dash> [permission...]"
        shift 4
        RESP="$(gg_role_update "$ROLE_ID" "$NAME" "$@")" || exit $?
        echo "$RESP" | jq .
        ;;
      delete)
        ROLE_ID="${3:-}"
        gg_require "$ROLE_ID" "Usage: partner_ops.sh role delete <roleId>"
        gg_role_delete "$ROLE_ID"
        ;;
      *)
        gg_die "$GG_EXIT_USAGE" "Unknown role subcommand: $SUB"
        ;;
    esac
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "$USAGE"
    ;;
esac
