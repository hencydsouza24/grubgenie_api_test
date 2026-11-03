#!/usr/bin/env bash
# Non-admin-bearer verbs for the long tail of small ops/diagnostic endpoints: the agents module
# (API key / no-auth), debug health/connections, the WhatsApp click redirect, and the voice tool
# webhook. Expressed over http.sh + json.sh. No raw curl here. Sourced by bootstrap.sh.
#
# Most of these endpoints need no GrubGenie diner/partner session at all (confirmed per-route
# below), so — unlike api.sh/api_admin_misc.sh — most functions here resolve the base URL
# directly via `gg_resolve_base` instead of `gg_session_get base`, the same way
# fetch_menu.sh's `branches` command avoids forcing an auth flow for a route that doesn't need
# one. The one exception (gg_debug_connections) needs an admin bearer token, which still goes
# through the normal session machinery.
#
# IMPORTANT: every `var="$(some_function ...)"` line below is followed by `|| exit $?` — see
# api.sh's header comment for why this is load-bearing, not defensive style. Any new function
# added to this file must follow the same pattern.

[ "${BASH_SOURCE[0]}" = "$0" ] && { echo "lib/api_misc.sh is a library — source it, don't execute it." >&2; exit 1; }

# --- Agents module ---

# gg_agents_topic <topicKey> <partnerId> [branchId] — GET /v1/agents/knowledge-base/topics/:topicKey.
# Auth is `authApiKey()` + `requireApiKeyPartnerAccess`, i.e. a literal `X-Api-Key` header (NOT
# Authorization: Bearer) — confirmed against src/routes/v1/agents/knowledgeBase.route.ts and
# src/modules/apiKey/apiKey.strategy.ts (passport-headerapikey, header 'X-Api-Key', no prefix).
# Reuses GG_WABA_MIDDLEWARE_API_KEY — same service-account key as the admin WABA resolve routes,
# not a second credential.
gg_agents_topic() {
  local topic_key="$1" partner_id="$2" branch_id="${3:-}"
  gg_require "$topic_key" "Usage: agents topic <topicKey> <partnerId> [branchId]"
  gg_require "$partner_id" "Usage: agents topic <topicKey> <partnerId> [branchId]"
  gg_load_credentials
  gg_require "${GG_WABA_MIDDLEWARE_API_KEY:-}" "GG_WABA_MIDDLEWARE_API_KEY not set — see scripts/config/credentials.example.env"
  local base
  base="$(gg_resolve_base)" || exit $?
  local -a query=(--query "partnerId=${partner_id}")
  [ -n "$branch_id" ] && query+=(--query "branchId=${branch_id}")
  gg_http_or_die "agents topic" GET "${base}/v1/agents/knowledge-base/topics/${topic_key}" \
    --header "X-Api-Key: ${GG_WABA_MIDDLEWARE_API_KEY}" "${query[@]+"${query[@]}"}"
}

# gg_agents_partner_info <partnerId> [branchId] — GET /v1/agents/partner/:partnerId.
# NO auth middleware at all — confirmed against src/routes/v1/agents/partner.route.ts (an
# unusual but real finding, not a mistake).
gg_agents_partner_info() {
  local partner_id="$1" branch_id="${2:-}"
  gg_require "$partner_id" "Usage: agents partner-info <partnerId> [branchId]"
  local base
  base="$(gg_resolve_base)" || exit $?
  local -a query=()
  [ -n "$branch_id" ] && query+=(--query "branchId=${branch_id}")
  gg_http_or_die "agents partner-info" GET "${base}/v1/agents/partner/${partner_id}" "${query[@]+"${query[@]}"}"
}

# --- Debug ---

# gg_debug_health — GET /v1/health, NOT /v1/debug/health. The audit this task was scoped from
# assumed a GET /v1/debug/health with zero auth; the real debug.route.ts has no /health endpoint
# at all (its routes are /memory, /gc, /heap-snapshot, /heap-stats, /active-handles,
# /connections, ALL behind `router.use(auth(permissions.sysInfo.getSysInfo))`). The actual
# zero-auth health check is a SEPARATE top-level route mounted at /v1/health
# (src/routes/v1/health.route.ts, src/routes/v1/index.ts) — that's what this function calls.
gg_debug_health() {
  local base
  base="$(gg_resolve_base)" || exit $?
  gg_http_or_die "debug health" GET "${base}/v1/health"
}

gg_debug_connections() {
  local base token
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  gg_http_or_die "debug connections" GET "${base}/v1/debug/connections" --token "$token"
}

# --- Redirect ---

# gg_redirect <buttonIndex> <ref> — GET /v1/redirect/:buttonIndex/:ref. Public, no auth. A
# WhatsApp click-tracking redirect that 302s to the real destination.
#
# CAVEAT: gg_http (lib/http.sh) hardcodes curl's `-L`, i.e. it always FOLLOWS redirects — there
# is no way to observe the redirect route's own 3xx through the existing transport; `GG_HTTP_STATUS`
# ends up being the FINAL destination's status after following every hop, not the redirect's.
# Per this task's own instruction not to rearchitect http.sh for this one case, this is called
# with `--expect any` and the (post-redirect) status is surfaced to the caller to interpret —
# it is NOT proof the redirect route itself returned a 3xx.
gg_redirect() {
  local button_index="$1" ref="$2"
  gg_require "$button_index" "Usage: redirect <buttonIndex> <ref>"
  gg_require "$ref" "Usage: redirect <buttonIndex> <ref>"
  local base status body
  base="$(gg_resolve_base)" || exit $?
  # `|| true`, not a bare assignment — gg_http can return non-zero (e.g. 7 on a transport
  # failure) even under --expect any, and this function wants to REPORT that status, not have
  # `set -e` kill the script on this line. `body` is only captured to keep gg_http's response
  # body off this script's own stdout (never used afterward — the real payload is `status`).
  # shellcheck disable=SC2034
  body="$(gg_http GET "${base}/v1/redirect/${button_index}/${ref}" --expect any)" || true
  status="$(gg_http_status)"
  jq -n --arg status "$status" --arg note "status is POST-redirect (the transport layer auto-follows it); the route's own 3xx is not observable through gg_http — see api_misc.sh" \
    '{status: $status, note: $note}'
}

# --- Voice tool webhook ---

# gg_voice_tool_webhook <tool> [key=value ...] — GET /v1/voice/tools/:toolKey/:tool.
#
# :toolKey is NOT taken as a CLI argument, deliberately: it's a real per-partner provisioned
# secret (gatewayController.runTool hashes it and compares against a per-partner stored hash in
# the DB — this skill can't generate a valid one), not a public test fixture like the other path
# params in this file. So it's sourced from GG_VOICE_TOOL_KEY in credentials.env, the same way
# gg_pos_config_setup takes zero CLI args for GG_PETPOOJA_APP_SECRET — never typed on the
# command line. Extra key=value pairs become query params — e.g. for `tool=availability`:
# partnerId=... branchId=... date=... partySize=...
gg_voice_tool_webhook() {
  local tool="$1"; shift
  gg_require "$tool" "Usage: voice-webhook <tool> [key=value ...] (uses GG_VOICE_TOOL_KEY)"
  gg_load_credentials
  gg_require "${GG_VOICE_TOOL_KEY:-}" "GG_VOICE_TOOL_KEY not set — see scripts/config/credentials.example.env"
  local base
  base="$(gg_resolve_base)" || exit $?
  local -a query=()
  local kv
  for kv in "$@"; do
    query+=(--query "$kv")
  done
  gg_http_or_die "voice webhook" GET "${base}/v1/voice/tools/${GG_VOICE_TOOL_KEY}/${tool}" "${query[@]+"${query[@]}"}"
}
