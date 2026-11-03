#!/usr/bin/env bash
# Partner Voice domain verbs — HeyKoala voice-agent connection (saved config under
# /v1/partner/voice/connection) + call history/sync (/v1/partner/voice/calls, routed from
# src/modules/voice/calls.*). Expressed over http.sh + json.sh, exactly like api.sh. Not yet
# sourced by bootstrap.sh (wired centrally later to avoid collisions with sibling lib files being
# added in parallel) — scripts that need these functions source this file directly, after
# bootstrap.sh.
#
# IMPORTANT: every `var="$(some_function ...)"` line below is followed by `|| exit $?` — see
# api.sh's header comment for why this is load-bearing on bash 3.2 (macOS's default /bin/bash)
# and not just defensive style. Any new function added to this file must follow the same pattern.

[ "${BASH_SOURCE[0]}" = "$0" ] && { echo "lib/api_partner_voice.sh is a library — source it, don't execute it." >&2; exit 1; }

# --- Connection group (auth: manageReservationSettings) ---

gg_voice_connection_options() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "voice connection options" GET "${base}/v1/partner/voice/connection/options" --token "$partner_token"
}

# gg_voice_validate_key <api_key> — field is `apiKey` (confirmed in voice.validation.ts).
gg_voice_validate_key() {
  local api_key="$1"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  body="$(jq -n --arg apiKey "$api_key" '{apiKey: $apiKey}')" || exit $?
  gg_http_or_die "voice validate key" POST "${base}/v1/partner/voice/connection/validate-key" \
    --token "$partner_token" --json "$body"
}

gg_voice_connection_get() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "voice connection get" GET "${base}/v1/partner/voice/connection" --token "$partner_token"
}

# gg_voice_connection_save <agent_id> <phone_number_id> <call_flow_id> [api_key] — apiKey is
# optional on PUT (only required on validate-key); the other three are required.
gg_voice_connection_save() {
  local agent_id="$1" phone_number_id="$2" call_flow_id="$3" api_key="${4:-}"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  body="$(jq -n \
    --arg agentId "$agent_id" --arg phoneNumberId "$phone_number_id" \
    --arg callFlowId "$call_flow_id" --arg apiKey "$api_key" \
    '{agentId: $agentId, phoneNumberId: $phoneNumberId, callFlowId: $callFlowId}
     + (if $apiKey != "" then {apiKey: $apiKey} else {} end)')" || exit $?
  gg_http_or_die "voice connection save" PUT "${base}/v1/partner/voice/connection" \
    --token "$partner_token" --json "$body"
}

# gg_voice_rotate_tool_key — route is `/connection/rotate-tool-key`, not `/connection/rotate-key`.
gg_voice_rotate_tool_key() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "voice rotate tool key" POST "${base}/v1/partner/voice/connection/rotate-tool-key" --token "$partner_token"
}

# gg_voice_connection_test <branch_id> <date YYYY-MM-DD> <party_size>
gg_voice_connection_test() {
  local branch_id="$1" date="$2" party_size="$3"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  body="$(jq -n --arg branchId "$branch_id" --arg date "$date" --argjson partySize "$party_size" \
    '{branchId: $branchId, date: $date, partySize: $partySize}')" || exit $?
  gg_http_or_die "voice connection test" POST "${base}/v1/partner/voice/connection/test" \
    --token "$partner_token" --json "$body"
}

gg_voice_go_live() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "voice go live" POST "${base}/v1/partner/voice/connection/go-live" --token "$partner_token"
}

# gg_voice_connection_delete → prints the response message (controller returns `result: {}`, so
# the message is the only useful signal here — same shape as gg_table_set_status).
gg_voice_connection_delete() {
  local base partner_token resp
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  resp="$(gg_http_or_die "voice connection delete" DELETE "${base}/v1/partner/voice/connection" --token "$partner_token")" || exit $?
  gg_json_message "$resp"
}

# --- Calls group (auth: getReservations for reads, manageReservationSettings for sync) ---

# gg_voice_calls_list [key=value ...] — zero or more optional query pairs (page, limit, direction,
# from, to, branchId, outcome, q — all optional per calls.validation.ts). The `${q[@]+"${q[@]}"}`
# expansion (not a bare `"${q[@]}"`) is deliberate: under `set -u` on bash 3.2 (macOS default),
# expanding a genuinely empty array with the bare form is a fatal "unbound variable", not a no-op.
gg_voice_calls_list() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  local -a q=()
  local kv
  for kv in "$@"; do q+=(--query "$kv"); done
  gg_http_or_die "voice calls list" GET "${base}/v1/partner/voice/calls" --token "$partner_token" "${q[@]+"${q[@]}"}"
}

# gg_voice_calls_stats [key=value ...] — same query shape as list (confirmed: both routes share
# callsValidation.listCalls, there is no separate stats-only schema).
gg_voice_calls_stats() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  local -a q=()
  local kv
  for kv in "$@"; do q+=(--query "$kv"); done
  gg_http_or_die "voice calls stats" GET "${base}/v1/partner/voice/calls/stats" --token "$partner_token" "${q[@]+"${q[@]}"}"
}

gg_voice_calls_sync() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "voice calls sync" POST "${base}/v1/partner/voice/calls/sync" --token "$partner_token"
}

# gg_voice_calls_linked <link_key> <link_id> — link_key is exactly `reservationId` or `inquiryId`
# (the route validates them as mutually exclusive — `.xor('reservationId', 'inquiryId')`). Mirrors
# api.sh's gg_order_create <cart_id> <line_key> <line_id> pattern: the type is passed explicitly
# as data rather than guessed from the id's shape (both are plain ObjectId strings, so there is no
# way to infer which one was meant).
gg_voice_calls_linked() {
  local link_key="$1" link_id="$2"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "voice calls linked" GET "${base}/v1/partner/voice/calls/linked" \
    --token "$partner_token" --query "${link_key}=${link_id}"
}

gg_voice_calls_get() {
  local call_id="$1"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "voice call get" GET "${base}/v1/partner/voice/calls/${call_id}" --token "$partner_token"
}
