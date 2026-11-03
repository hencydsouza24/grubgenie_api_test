#!/usr/bin/env bash
# Admin Genie — fleet/session inspection and per-thread control (signal, chat, evict, end).
# Usage: bash genie_admin.sh fleet
#        bash genie_admin.sh sessions [page] [limit] [fromTimestamp] [toTimestamp]
#        bash genie_admin.sh thread get <threadId>
#        bash genie_admin.sh thread activity <threadId> [limit]
#        bash genie_admin.sh thread evict <threadId>
#        bash genie_admin.sh thread signal <threadId> <type> [payloadJson]
#        bash genie_admin.sh thread chat <threadId> <message>
#        bash genie_admin.sh thread end <threadId>
#        bash genie_admin.sh spawn <dinerId> <cartId> <branchId> <accountId> <partnerId> <tableId>
# threadId is a composite "diner-agent:<cartId>:<dinerId>" (see buildThreadId in
# src/modules/genieV2/genie.helpers.ts) — build it from a spawned session's cartId/dinerId.
# Requires admin credentials (see scripts/config/credentials.example.env) — gg_admin_token
# lazily logs in and caches the token.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

USAGE="Usage: genie_admin.sh fleet|sessions|thread|spawn [args]"

CMD="${1:-}"
gg_require "$CMD" "$USAGE"

case "$CMD" in
  fleet)
    RESP="$(gg_genie_fleet)" || exit $?
    ;;

  sessions)
    RESP="$(gg_genie_sessions "${2:-}" "${3:-}" "${4:-}" "${5:-}")" || exit $?
    ;;

  thread)
    SUB="${2:-}"
    THREAD_ID="${3:-}"
    gg_require "$SUB" "Usage: genie_admin.sh thread get|activity|evict|signal|chat|end <threadId> [args]"
    gg_require "$THREAD_ID" "Usage: genie_admin.sh thread $SUB <threadId> [args]"

    case "$SUB" in
      get)
        RESP="$(gg_genie_thread_get "$THREAD_ID")" || exit $?
        ;;
      activity)
        RESP="$(gg_genie_thread_activity "$THREAD_ID" "${4:-}")" || exit $?
        ;;
      evict)
        RESP="$(gg_genie_thread_evict "$THREAD_ID")" || exit $?
        ;;
      signal)
        SIGNAL_TYPE="${4:-}" PAYLOAD="${5:-}"
        gg_require "$SIGNAL_TYPE" "Usage: genie_admin.sh thread signal <threadId> <type> [payloadJson]"
        RESP="$(gg_genie_thread_signal "$THREAD_ID" "$SIGNAL_TYPE" "$PAYLOAD")" || exit $?
        ;;
      chat)
        MESSAGE="${4:-}"
        gg_require "$MESSAGE" "Usage: genie_admin.sh thread chat <threadId> <message>"
        RESP="$(gg_genie_thread_chat "$THREAD_ID" "$MESSAGE")" || exit $?
        ;;
      end)
        RESP="$(gg_genie_thread_end "$THREAD_ID")" || exit $?
        ;;
      *)
        gg_die "$GG_EXIT_USAGE" "Unknown thread subcommand: $SUB. Usage: genie_admin.sh thread get|activity|evict|signal|chat|end <threadId> [args]"
        ;;
    esac
    ;;

  spawn)
    DINER_ID="${2:-}" CART_ID="${3:-}" BRANCH_ID="${4:-}" ACCOUNT_ID="${5:-}" PARTNER_ID="${6:-}" TABLE_ID="${7:-}"
    SPAWN_USAGE="Usage: genie_admin.sh spawn <dinerId> <cartId> <branchId> <accountId> <partnerId> <tableId>"
    gg_require "$DINER_ID" "$SPAWN_USAGE"
    gg_require "$CART_ID" "$SPAWN_USAGE"
    gg_require "$BRANCH_ID" "$SPAWN_USAGE"
    gg_require "$ACCOUNT_ID" "$SPAWN_USAGE"
    gg_require "$PARTNER_ID" "$SPAWN_USAGE"
    gg_require "$TABLE_ID" "$SPAWN_USAGE"
    RESP="$(gg_genie_spawn "$DINER_ID" "$CART_ID" "$BRANCH_ID" "$ACCOUNT_ID" "$PARTNER_ID" "$TABLE_ID")" || exit $?
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "Unknown command: $CMD. $USAGE"
    ;;
esac

echo "$RESP" | jq .
