#!/usr/bin/env bash
# Admin partner management — list/view/patch partners, read and update branch agent contexts.
# Usage: bash admin_partner.sh list [key=value ...]
#        bash admin_partner.sh get <accountId>
#        bash admin_partner.sh patch <accountId> <key=value> [key=value ...]
#        bash admin_partner.sh agent-contexts
#        bash admin_partner.sh branch-contexts <accountId>
#        bash admin_partner.sh branch-context get <accountId> <branchId>
#        bash admin_partner.sh branch-context put <accountId> <branchId> <context>
# The path param is accountId, NOT partnerId (the partner.info module keys partners by
# accountId). Requires admin credentials (see scripts/config/credentials.example.env) —
# gg_admin_token lazily logs in and caches the token.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

USAGE="Usage: admin_partner.sh list|get|patch|agent-contexts|branch-contexts|branch-context [args]"

CMD="${1:-}"
gg_require "$CMD" "$USAGE"

case "$CMD" in
  list)
    RESP="$(gg_partner_list "${@:2}")" || exit $?
    ;;

  get)
    ACCOUNT_ID="${2:-}"
    gg_require "$ACCOUNT_ID" "Usage: admin_partner.sh get <accountId>"
    RESP="$(gg_partner_get "$ACCOUNT_ID")" || exit $?
    ;;

  patch)
    ACCOUNT_ID="${2:-}"
    gg_require "$ACCOUNT_ID" "Usage: admin_partner.sh patch <accountId> <key=value> [key=value ...]"
    [ "$#" -ge 3 ] || gg_die "$GG_EXIT_USAGE" "Usage: admin_partner.sh patch <accountId> <key=value> [key=value ...]"
    RESP="$(gg_partner_patch "$ACCOUNT_ID" "${@:3}")" || exit $?
    ;;

  agent-contexts)
    RESP="$(gg_partner_agent_contexts)" || exit $?
    ;;

  branch-contexts)
    ACCOUNT_ID="${2:-}"
    gg_require "$ACCOUNT_ID" "Usage: admin_partner.sh branch-contexts <accountId>"
    RESP="$(gg_partner_branch_contexts "$ACCOUNT_ID")" || exit $?
    ;;

  branch-context)
    SUB="${2:-}"
    gg_require "$SUB" "Usage: admin_partner.sh branch-context get|put <accountId> <branchId> [context]"
    case "$SUB" in
      get)
        ACCOUNT_ID="${3:-}" BRANCH_ID="${4:-}"
        gg_require "$ACCOUNT_ID" "Usage: admin_partner.sh branch-context get <accountId> <branchId>"
        gg_require "$BRANCH_ID" "Usage: admin_partner.sh branch-context get <accountId> <branchId>"
        RESP="$(gg_partner_branch_context_get "$ACCOUNT_ID" "$BRANCH_ID")" || exit $?
        ;;
      put)
        ACCOUNT_ID="${3:-}" BRANCH_ID="${4:-}" CONTEXT="${5:-}"
        gg_require "$ACCOUNT_ID" "Usage: admin_partner.sh branch-context put <accountId> <branchId> <context>"
        gg_require "$BRANCH_ID" "Usage: admin_partner.sh branch-context put <accountId> <branchId> <context>"
        gg_require "$CONTEXT" "Usage: admin_partner.sh branch-context put <accountId> <branchId> <context>"
        RESP="$(gg_partner_branch_context_put "$ACCOUNT_ID" "$BRANCH_ID" "$CONTEXT")" || exit $?
        ;;
      *)
        gg_die "$GG_EXIT_USAGE" "Unknown branch-context subcommand: $SUB. Usage: admin_partner.sh branch-context get|put <accountId> <branchId> [context]"
        ;;
    esac
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "Unknown command: $CMD. $USAGE"
    ;;
esac

echo "$RESP" | jq .
