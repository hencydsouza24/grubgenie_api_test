#!/usr/bin/env bash
# Admin WABA Flows — flow definitions and their deployments to connected WABAs.
# Usage: bash waba_flows.sh definitions list [key=value ...]
#        bash waba_flows.sh definitions create <key> <name> <categories-csv> <flowJson> [autoProvision]
#        bash waba_flows.sh definitions get <definitionId>
#        bash waba_flows.sh definitions update <definitionId> [name] [categories-csv] [flowJson] [autoProvision]
#        bash waba_flows.sh definitions release <definitionId>
#        bash waba_flows.sh deployments list [key=value ...]
#        bash waba_flows.sh deployments retry <deploymentId>
#        bash waba_flows.sh deployments deprecate <deploymentId>
# categories-csv is comma-separated, e.g. "SIGN_UP,CONTACT_US". Pass "" for an update field you
# don't want to change. Requires admin credentials (see scripts/config/credentials.example.env)
# — gg_admin_token lazily logs in and caches the token; manageFlows is super-admin-only, so this
# always uses the admin bearer token, never an X-Api-Key.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

USAGE="Usage: waba_flows.sh definitions list|create|get|update|release [args] | deployments list|retry|deprecate [args]"

CMD="${1:-}"
gg_require "$CMD" "$USAGE"

SUB="${2:-}"
gg_require "$SUB" "$USAGE"

case "$CMD" in
  definitions)
    case "$SUB" in
      list)
        RESP="$(gg_waba_flow_definitions_list "${@:3}")" || exit $?
        ;;
      create)
        KEY="${3:-}" NAME="${4:-}" CATEGORIES="${5:-}" FLOW_JSON="${6:-}" AUTO_PROVISION="${7:-}"
        gg_require "$KEY" "Usage: waba_flows.sh definitions create <key> <name> <categories-csv> <flowJson> [autoProvision]"
        gg_require "$NAME" "Usage: waba_flows.sh definitions create <key> <name> <categories-csv> <flowJson> [autoProvision]"
        gg_require "$CATEGORIES" "Usage: waba_flows.sh definitions create <key> <name> <categories-csv> <flowJson> [autoProvision]"
        gg_require "$FLOW_JSON" "Usage: waba_flows.sh definitions create <key> <name> <categories-csv> <flowJson> [autoProvision]"
        RESP="$(gg_waba_flow_definition_create "$KEY" "$NAME" "$CATEGORIES" "$FLOW_JSON" "$AUTO_PROVISION")" || exit $?
        ;;
      get)
        DEFINITION_ID="${3:-}"
        gg_require "$DEFINITION_ID" "Usage: waba_flows.sh definitions get <definitionId>"
        RESP="$(gg_waba_flow_definition_get "$DEFINITION_ID")" || exit $?
        ;;
      update)
        DEFINITION_ID="${3:-}" NAME="${4:-}" CATEGORIES="${5:-}" FLOW_JSON="${6:-}" AUTO_PROVISION="${7:-}"
        gg_require "$DEFINITION_ID" "Usage: waba_flows.sh definitions update <definitionId> [name] [categories-csv] [flowJson] [autoProvision]"
        RESP="$(gg_waba_flow_definition_update "$DEFINITION_ID" "$NAME" "$CATEGORIES" "$FLOW_JSON" "$AUTO_PROVISION")" || exit $?
        ;;
      release)
        DEFINITION_ID="${3:-}"
        gg_require "$DEFINITION_ID" "Usage: waba_flows.sh definitions release <definitionId>"
        RESP="$(gg_waba_flow_definition_release "$DEFINITION_ID")" || exit $?
        ;;
      *)
        gg_die "$GG_EXIT_USAGE" "Unknown subcommand: $SUB. Usage: waba_flows.sh definitions list|create|get|update|release [args]"
        ;;
    esac
    ;;

  deployments)
    case "$SUB" in
      list)
        RESP="$(gg_waba_flow_deployments_list "${@:3}")" || exit $?
        ;;
      retry)
        DEPLOYMENT_ID="${3:-}"
        gg_require "$DEPLOYMENT_ID" "Usage: waba_flows.sh deployments retry <deploymentId>"
        RESP="$(gg_waba_flow_deployment_retry "$DEPLOYMENT_ID")" || exit $?
        ;;
      deprecate)
        DEPLOYMENT_ID="${3:-}"
        gg_require "$DEPLOYMENT_ID" "Usage: waba_flows.sh deployments deprecate <deploymentId>"
        RESP="$(gg_waba_flow_deployment_deprecate "$DEPLOYMENT_ID")" || exit $?
        ;;
      *)
        gg_die "$GG_EXIT_USAGE" "Unknown subcommand: $SUB. Usage: waba_flows.sh deployments list|retry|deprecate [args]"
        ;;
    esac
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "Unknown command group: $CMD. $USAGE"
    ;;
esac

echo "$RESP" | jq .
