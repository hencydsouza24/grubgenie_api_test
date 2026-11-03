#!/usr/bin/env bash
# Admin settlement operations — list/summarize/calculate/create/mark-settled settlements.
# Usage: bash settlement.sh admin list [key=value ...]
#        bash settlement.sh admin summary
#        bash settlement.sh admin partner <partnerId> [key=value ...]
#        bash settlement.sh admin branch <branchId> [key=value ...]
#        bash settlement.sh admin calculate <partnerId> <periodFrom> <periodTo> [branchId]
#        bash settlement.sh admin batch-calculate <periodFrom> <periodTo> <partnerId[:branchId]> [...]
#        bash settlement.sh admin create <partnerId> <periodFrom> <periodTo> [branchId] [notes]
#        bash settlement.sh admin batch-create <periodFrom> <periodTo> <partnerId[:branchId]> [...]
#        bash settlement.sh admin get <settlementId>
#        bash settlement.sh admin mark-settled <settlementId> [notes]
# periodFrom/periodTo are YYYY-MM-DD dates. Requires admin credentials (see
# scripts/config/credentials.example.env) — gg_admin_token lazily logs in and caches the token.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

USAGE="Usage: settlement.sh admin list|summary|partner|branch|calculate|batch-calculate|create|batch-create|get|mark-settled [args]"

CMD="${1:-}"
gg_require "$CMD" "$USAGE"
[ "$CMD" = "admin" ] || gg_die "$GG_EXIT_USAGE" "Unknown command group: $CMD (expected: admin)"

SUB="${2:-}"
gg_require "$SUB" "$USAGE"

case "$SUB" in
  list)
    RESP="$(gg_settlement_list "${@:3}")" || exit $?
    echo "$RESP" | jq .
    ;;

  summary)
    RESP="$(gg_settlement_summary)" || exit $?
    echo "$RESP" | jq .
    ;;

  partner)
    PARTNER_ID="${3:-}"
    gg_require "$PARTNER_ID" "Usage: settlement.sh admin partner <partnerId> [key=value ...]"
    RESP="$(gg_settlement_partner "$PARTNER_ID" "${@:4}")" || exit $?
    echo "$RESP" | jq .
    ;;

  branch)
    BRANCH_ID="${3:-}"
    gg_require "$BRANCH_ID" "Usage: settlement.sh admin branch <branchId> [key=value ...]"
    RESP="$(gg_settlement_branch "$BRANCH_ID" "${@:4}")" || exit $?
    echo "$RESP" | jq .
    ;;

  calculate)
    PARTNER_ID="${3:-}" PERIOD_FROM="${4:-}" PERIOD_TO="${5:-}" BRANCH_ID="${6:-}"
    gg_require "$PARTNER_ID" "Usage: settlement.sh admin calculate <partnerId> <periodFrom> <periodTo> [branchId]"
    gg_require "$PERIOD_FROM" "Usage: settlement.sh admin calculate <partnerId> <periodFrom> <periodTo> [branchId]"
    gg_require "$PERIOD_TO" "Usage: settlement.sh admin calculate <partnerId> <periodFrom> <periodTo> [branchId]"
    RESP="$(gg_settlement_calculate "$PARTNER_ID" "$PERIOD_FROM" "$PERIOD_TO" "$BRANCH_ID")" || exit $?
    echo "$RESP" | jq .
    ;;

  batch-calculate)
    PERIOD_FROM="${3:-}" PERIOD_TO="${4:-}"
    gg_require "$PERIOD_FROM" "Usage: settlement.sh admin batch-calculate <periodFrom> <periodTo> <partnerId[:branchId]> [...]"
    gg_require "$PERIOD_TO" "Usage: settlement.sh admin batch-calculate <periodFrom> <periodTo> <partnerId[:branchId]> [...]"
    [ "$#" -ge 5 ] || gg_die "$GG_EXIT_USAGE" "Usage: settlement.sh admin batch-calculate <periodFrom> <periodTo> <partnerId[:branchId]> [...]"
    RESP="$(gg_settlement_calculate_batch "$PERIOD_FROM" "$PERIOD_TO" "${@:5}")" || exit $?
    echo "$RESP" | jq .
    ;;

  create)
    PARTNER_ID="${3:-}" PERIOD_FROM="${4:-}" PERIOD_TO="${5:-}" BRANCH_ID="${6:-}" NOTES="${7:-}"
    gg_require "$PARTNER_ID" "Usage: settlement.sh admin create <partnerId> <periodFrom> <periodTo> [branchId] [notes]"
    gg_require "$PERIOD_FROM" "Usage: settlement.sh admin create <partnerId> <periodFrom> <periodTo> [branchId] [notes]"
    gg_require "$PERIOD_TO" "Usage: settlement.sh admin create <partnerId> <periodFrom> <periodTo> [branchId] [notes]"
    RESP="$(gg_settlement_create "$PARTNER_ID" "$PERIOD_FROM" "$PERIOD_TO" "$BRANCH_ID" "$NOTES")" || exit $?
    echo "$RESP" | jq .
    ;;

  batch-create)
    PERIOD_FROM="${3:-}" PERIOD_TO="${4:-}"
    gg_require "$PERIOD_FROM" "Usage: settlement.sh admin batch-create <periodFrom> <periodTo> <partnerId[:branchId]> [...]"
    gg_require "$PERIOD_TO" "Usage: settlement.sh admin batch-create <periodFrom> <periodTo> <partnerId[:branchId]> [...]"
    [ "$#" -ge 5 ] || gg_die "$GG_EXIT_USAGE" "Usage: settlement.sh admin batch-create <periodFrom> <periodTo> <partnerId[:branchId]> [...]"
    RESP="$(gg_settlement_create_batch "$PERIOD_FROM" "$PERIOD_TO" "${@:5}")" || exit $?
    echo "$RESP" | jq .
    ;;

  get)
    SETTLEMENT_ID="${3:-}"
    gg_require "$SETTLEMENT_ID" "Usage: settlement.sh admin get <settlementId>"
    RESP="$(gg_settlement_get "$SETTLEMENT_ID")" || exit $?
    echo "$RESP" | jq .
    ;;

  mark-settled)
    SETTLEMENT_ID="${3:-}" NOTES="${4:-}"
    gg_require "$SETTLEMENT_ID" "Usage: settlement.sh admin mark-settled <settlementId> [notes]"
    RESP="$(gg_settlement_mark_settled "$SETTLEMENT_ID" "$NOTES")" || exit $?
    echo "$RESP" | jq .
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "Unknown subcommand: $SUB. $USAGE"
    ;;
esac
