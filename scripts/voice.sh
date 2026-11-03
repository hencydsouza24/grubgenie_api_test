#!/usr/bin/env bash
# Partner Voice (HeyKoala connection + call history) — /v1/partner/voice/*.
# Usage: bash voice.sh connection options
#        bash voice.sh connection validate <apiKey>
#        bash voice.sh connection get
#        bash voice.sh connection update <agentId> <phoneNumberId> <callFlowId> [apiKey]
#        bash voice.sh connection rotate-key
#        bash voice.sh connection test <branchId> <date YYYY-MM-DD> <partySize>
#        bash voice.sh connection go-live
#        bash voice.sh connection delete
#        bash voice.sh calls list [key=value ...]
#        bash voice.sh calls stats [key=value ...]
#        bash voice.sh calls sync
#        bash voice.sh calls linked <reservationId|inquiryId> <id>
#        bash voice.sh calls get <callId>
#
# All routes use partner bearer auth. `calls linked` takes the xor key explicitly as its own
# argument (reservationId or inquiryId) rather than guessing from the id's shape — both are plain
# ObjectId strings, so there is no way to infer which one was meant.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

USAGE="Usage: voice.sh connection options|validate|get|update|rotate-key|test|go-live|delete | calls list|stats|sync|linked|get [args]"

GROUP="${1:-}"
gg_require "$GROUP" "$USAGE"

case "$GROUP" in
  connection)
    SUB="${2:-}"
    gg_require "$SUB" "Usage: voice.sh connection options|validate <apiKey>|get|update <agentId> <phoneNumberId> <callFlowId> [apiKey]|rotate-key|test <branchId> <date> <partySize>|go-live|delete"
    case "$SUB" in
      options)
        RESP="$(gg_voice_connection_options)" || exit $?
        echo "$RESP" | jq .
        ;;
      validate)
        API_KEY="${3:-}"
        gg_require "$API_KEY" "Usage: voice.sh connection validate <apiKey>"
        RESP="$(gg_voice_validate_key "$API_KEY")" || exit $?
        echo "$RESP" | jq .
        ;;
      get)
        RESP="$(gg_voice_connection_get)" || exit $?
        echo "$RESP" | jq .
        ;;
      update)
        AGENT_ID="${3:-}" PHONE_NUMBER_ID="${4:-}" CALL_FLOW_ID="${5:-}" API_KEY="${6:-}"
        gg_require "$AGENT_ID" "Usage: voice.sh connection update <agentId> <phoneNumberId> <callFlowId> [apiKey]"
        gg_require "$PHONE_NUMBER_ID" "Usage: voice.sh connection update <agentId> <phoneNumberId> <callFlowId> [apiKey]"
        gg_require "$CALL_FLOW_ID" "Usage: voice.sh connection update <agentId> <phoneNumberId> <callFlowId> [apiKey]"
        RESP="$(gg_voice_connection_save "$AGENT_ID" "$PHONE_NUMBER_ID" "$CALL_FLOW_ID" "$API_KEY")" || exit $?
        echo "$RESP" | jq .
        ;;
      rotate-key)
        RESP="$(gg_voice_rotate_tool_key)" || exit $?
        echo "$RESP" | jq .
        ;;
      test)
        BRANCH_ID="${3:-}" DATE="${4:-}" PARTY_SIZE="${5:-}"
        gg_require "$BRANCH_ID" "Usage: voice.sh connection test <branchId> <date YYYY-MM-DD> <partySize>"
        gg_require "$DATE" "Usage: voice.sh connection test <branchId> <date YYYY-MM-DD> <partySize>"
        gg_require "$PARTY_SIZE" "Usage: voice.sh connection test <branchId> <date YYYY-MM-DD> <partySize>"
        RESP="$(gg_voice_connection_test "$BRANCH_ID" "$DATE" "$PARTY_SIZE")" || exit $?
        echo "$RESP" | jq .
        ;;
      go-live)
        RESP="$(gg_voice_go_live)" || exit $?
        echo "$RESP" | jq .
        ;;
      delete)
        gg_voice_connection_delete
        ;;
      *)
        gg_die "$GG_EXIT_USAGE" "Unknown connection subcommand: $SUB"
        ;;
    esac
    ;;

  calls)
    SUB="${2:-}"
    gg_require "$SUB" "Usage: voice.sh calls list|stats|sync|linked <reservationId|inquiryId> <id>|get <callId>"
    case "$SUB" in
      list)
        shift 2
        RESP="$(gg_voice_calls_list "$@")" || exit $?
        echo "$RESP" | jq .
        ;;
      stats)
        shift 2
        RESP="$(gg_voice_calls_stats "$@")" || exit $?
        echo "$RESP" | jq .
        ;;
      sync)
        RESP="$(gg_voice_calls_sync)" || exit $?
        echo "$RESP" | jq .
        ;;
      linked)
        LINK_KEY="${3:-}" LINK_ID="${4:-}"
        gg_require "$LINK_KEY" "Usage: voice.sh calls linked <reservationId|inquiryId> <id>"
        gg_require "$LINK_ID" "Usage: voice.sh calls linked <reservationId|inquiryId> <id>"
        case "$LINK_KEY" in
          reservationId|inquiryId) ;;
          *) gg_die "$GG_EXIT_USAGE" "Usage: voice.sh calls linked <reservationId|inquiryId> <id>" ;;
        esac
        RESP="$(gg_voice_calls_linked "$LINK_KEY" "$LINK_ID")" || exit $?
        echo "$RESP" | jq .
        ;;
      get)
        CALL_ID="${3:-}"
        gg_require "$CALL_ID" "Usage: voice.sh calls get <callId>"
        RESP="$(gg_voice_calls_get "$CALL_ID")" || exit $?
        echo "$RESP" | jq .
        ;;
      *)
        gg_die "$GG_EXIT_USAGE" "Unknown calls subcommand: $SUB"
        ;;
    esac
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "$USAGE"
    ;;
esac
