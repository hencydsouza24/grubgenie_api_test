#!/usr/bin/env bash
# Table split/merge/chair-borrow actions — additional to the basic list/status-update ops already
# covered by reset_tables.sh and gg_tables_list/gg_table_set_status in lib/api.sh.
# Usage: bash table_actions.sh split <tableId> <seg1> <seg2> [seg3] [seg4]
#        bash table_actions.sh merge <tableId>
#        bash table_actions.sh borrow-chair <tableId> <fromTableId> [count]
#        bash table_actions.sh return-chair <tableId> <borrowId>
#
# return-chair's route is DELETE /v1/partner/table/:tableId/borrow-chair/:borrowId — both the
# table and the specific borrow record's own id are path params (confirmed against
# table.route.ts); borrowId is the `_id` of an entry in `.result.borrowedChairs[]` returned by a
# prior `borrow-chair` call.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

USAGE="Usage: table_actions.sh split <tableId> <seg1> <seg2> [seg3] [seg4] | merge <tableId> | borrow-chair <tableId> <fromTableId> [count] | return-chair <tableId> <borrowId>"

CMD="${1:-}"
gg_require "$CMD" "$USAGE"

case "$CMD" in
  split)
    TABLE_ID="${2:-}"
    gg_require "$TABLE_ID" "$USAGE"
    shift 2
    [ "$#" -ge 2 ] || gg_die "$GG_EXIT_USAGE" "$USAGE"
    RESP="$(gg_table_split "$TABLE_ID" "$@")" || exit $?
    echo "$RESP" | jq .
    ;;

  merge)
    TABLE_ID="${2:-}"
    gg_require "$TABLE_ID" "$USAGE"
    RESP="$(gg_table_merge "$TABLE_ID")" || exit $?
    echo "$RESP" | jq .
    ;;

  borrow-chair)
    TABLE_ID="${2:-}" FROM_TABLE_ID="${3:-}" COUNT="${4:-}"
    gg_require "$TABLE_ID" "$USAGE"
    gg_require "$FROM_TABLE_ID" "$USAGE"
    RESP="$(gg_table_borrow_chair "$TABLE_ID" "$FROM_TABLE_ID" "$COUNT")" || exit $?
    echo "$RESP" | jq .
    ;;

  return-chair)
    TABLE_ID="${2:-}" BORROW_ID="${3:-}"
    gg_require "$TABLE_ID" "$USAGE"
    gg_require "$BORROW_ID" "$USAGE"
    RESP="$(gg_table_return_chair "$TABLE_ID" "$BORROW_ID")" || exit $?
    echo "$RESP" | jq .
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "$USAGE"
    ;;
esac
