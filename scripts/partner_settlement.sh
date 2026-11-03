#!/usr/bin/env bash
# Partner Settlement reads (read-only, partner bearer auth).
# Usage: bash partner_settlement.sh list [k=v ...]
#        bash partner_settlement.sh summary
#
# k=v filters for `list`: branchId, status, gateway, periodFrom, periodTo, sortBy, page, limit
# (listPartnerSettlements query schema). branchId is auto-scoped server-side for non-admin
# partner users, so it's rarely needed here.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

CMD="${1:-}"
gg_require "$CMD" "Usage: partner_settlement.sh list [k=v ...]|summary"

case "$CMD" in
  list)
    RESP="$(gg_partner_settlement_list "${@:2}")" || exit $?
    echo "$RESP" | jq '.result'
    ;;
  summary)
    RESP="$(gg_partner_settlement_summary)" || exit $?
    echo "$RESP" | jq '.result'
    ;;
  *)
    gg_die "$GG_EXIT_USAGE" "Unknown command: $CMD (expected list|summary)"
    ;;
esac
