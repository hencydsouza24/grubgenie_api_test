#!/usr/bin/env bash
# Non-admin-bearer long-tail ops/diagnostic groups: the agents module, debug health/connections,
# the WhatsApp click redirect, and the voice tool webhook.
#
# Usage: bash misc_tools.sh <command> [args...]
#
# Commands:
#   agents topic <topicKey> <partnerId> [branchId]   requires GG_WABA_MIDDLEWARE_API_KEY
#   agents partner-info <partnerId> [branchId]       no auth
#   debug health                                     GET /v1/health (NOT /v1/debug/health — see
#                                                     gg_debug_health's comment in api_misc.sh)
#   debug connections                                admin bearer
#   redirect <buttonIndex> <ref>                     ref is `<tenantId>.<token>`; see the caveat
#                                                     in gg_redirect's comment — gg_http follows
#                                                     redirects, so the printed status is
#                                                     post-redirect, not the route's own 3xx
#   voice-webhook <tool> [key=value ...]             requires GG_VOICE_TOOL_KEY; e.g.
#                                                     voice-webhook availability partnerId=... \
#                                                       branchId=... date=... partySize=...
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"

USAGE="Usage: misc_tools.sh agents topic <topicKey> <partnerId> [branchId] | agents partner-info <partnerId> [branchId] | debug health | debug connections | redirect <buttonIndex> <ref> | voice-webhook <tool> [key=value ...]"

CMD="${1:-}"
gg_require "$CMD" "$USAGE"

case "$CMD" in
  agents)
    ACTION="${2:-}"
    case "$ACTION" in
      topic)         gg_agents_topic "${3:-}" "${4:-}" "${5:-}" ;;
      partner-info)  gg_agents_partner_info "${3:-}" "${4:-}" ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: misc_tools.sh agents topic <topicKey> <partnerId> [branchId] | partner-info <partnerId> [branchId]" ;;
    esac
    ;;

  debug)
    ACTION="${2:-}"
    case "$ACTION" in
      health)      gg_debug_health ;;
      connections) gg_debug_connections ;;
      *) gg_die "$GG_EXIT_USAGE" "Usage: misc_tools.sh debug health|connections" ;;
    esac
    ;;

  redirect)
    gg_redirect "${2:-}" "${3:-}"
    ;;

  voice-webhook)
    TOOL="${2:-}"
    gg_require "$TOOL" "Usage: misc_tools.sh voice-webhook <tool> [key=value ...]"
    shift 2
    gg_voice_tool_webhook "$TOOL" "$@"
    ;;

  *)
    gg_die "$GG_EXIT_USAGE" "$USAGE"
    ;;
esac
