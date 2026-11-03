#!/usr/bin/env bash
# Admin-domain verbs for 5 admin API groups — Settlement, WABA Flows, Genie, Dashboard, Partner
# Mgmt — expressed over http.sh + json.sh, exactly like api.sh is for the diner/partner domain.
# No raw curl here. Sourced by bootstrap.sh.
#
# Every function here authenticates with gg_admin_token (lib/auth.sh), NOT gg_auth_admin
# directly — gg_admin_token lazily mints and caches a single admin bearer token in the session
# file, shared across every admin-scoped script instead of re-logging in on every call.
#
# IMPORTANT: every `var="$(some_function ...)"` line below is followed by `|| exit $?`. See
# api.sh's own header comment for why this is load-bearing on bash 3.2 (macOS's default
# /bin/bash), not defensive style. Any new function added to this file must follow the same
# pattern.

[ "${BASH_SOURCE[0]}" = "$0" ] && { echo "lib/api_admin.sh is a library — source it, don't execute it." >&2; exit 1; }

# --- Admin Settlement (/v1/admin/settlement) ---

# gg_settlement_list [key=value ...] — optional query filters: status, limit, page, partnerId,
# branchId, gateway, periodFrom, periodTo, sortBy, projectBy.
gg_settlement_list() {
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  local -a query_args=()
  local kv
  for kv in "$@"; do
    query_args+=(--query "$kv")
  done
  gg_http_or_die "settlement list" GET "${base}/v1/admin/settlement" --token "$admin_token" "${query_args[@]}"
}

gg_settlement_summary() {
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  gg_http_or_die "settlement summary" GET "${base}/v1/admin/settlement/summary" --token "$admin_token"
}

# gg_settlement_partner <partnerId> [key=value ...] — optional query filters: sortBy, limit, page.
gg_settlement_partner() {
  local partner_id="$1"; shift
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  local -a query_args=()
  local kv
  for kv in "$@"; do
    query_args+=(--query "$kv")
  done
  gg_http_or_die "partner settlements" GET "${base}/v1/admin/settlement/partners/${partner_id}" --token "$admin_token" "${query_args[@]}"
}

# gg_settlement_branch <branchId> [key=value ...] — optional query filters: sortBy, limit, page.
gg_settlement_branch() {
  local branch_id="$1"; shift
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  local -a query_args=()
  local kv
  for kv in "$@"; do
    query_args+=(--query "$kv")
  done
  gg_http_or_die "branch settlements" GET "${base}/v1/admin/settlement/branches/${branch_id}" --token "$admin_token" "${query_args[@]}"
}

# gg_settlement_calculate <partnerId> <periodFrom> <periodTo> [branchId] — preview only, writes
# nothing (unlike gg_settlement_create).
gg_settlement_calculate() {
  local partner_id="$1" period_from="$2" period_to="$3" branch_id="${4:-}"
  local base admin_token body
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  body="$(jq -n --arg p "$partner_id" --arg f "$period_from" --arg t "$period_to" --arg b "$branch_id" \
    '{partnerId: $p, periodFrom: $f, periodTo: $t} + (if $b != "" then {branchId: $b} else {} end)')" || exit $?
  gg_http_or_die "settlement calculate" POST "${base}/v1/admin/settlement/calculate" --token "$admin_token" --json "$body"
}

# _gg_settlement_targets <partnerId[:branchId]> [...] → prints a JSON array of {partnerId,
# branchId?} objects for the batch calculate/create endpoints' required `targets` field.
_gg_settlement_targets() {
  local targets_json="[]" target partner_id branch_id obj
  for target in "$@"; do
    partner_id="${target%%:*}"
    branch_id=""
    [[ "$target" == *:* ]] && branch_id="${target#*:}"
    if [ -n "$branch_id" ]; then
      obj="$(jq -n --arg p "$partner_id" --arg b "$branch_id" '{partnerId: $p, branchId: $b}')" || exit $?
    else
      obj="$(jq -n --arg p "$partner_id" '{partnerId: $p}')" || exit $?
    fi
    targets_json="$(jq --argjson o "$obj" '. + [$o]' <<< "$targets_json")" || exit $?
  done
  printf '%s' "$targets_json"
}

# gg_settlement_calculate_batch <periodFrom> <periodTo> <partnerId[:branchId]> [...]
gg_settlement_calculate_batch() {
  local period_from="$1" period_to="$2"; shift 2
  local base admin_token targets body
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  targets="$(_gg_settlement_targets "$@")" || exit $?
  body="$(jq -n --arg f "$period_from" --arg t "$period_to" --argjson targets "$targets" \
    '{periodFrom: $f, periodTo: $t, targets: $targets}')" || exit $?
  gg_http_or_die "settlement batch calculate" POST "${base}/v1/admin/settlement/batch/calculate" --token "$admin_token" --json "$body"
}

# gg_settlement_create <partnerId> <periodFrom> <periodTo> [branchId] [notes] — writes a real
# settlement record (unlike gg_settlement_calculate).
gg_settlement_create() {
  local partner_id="$1" period_from="$2" period_to="$3" branch_id="${4:-}" notes="${5:-}"
  local base admin_token body
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  body="$(jq -n --arg p "$partner_id" --arg f "$period_from" --arg t "$period_to" --arg b "$branch_id" --arg n "$notes" \
    '{partnerId: $p, periodFrom: $f, periodTo: $t}
     + (if $b != "" then {branchId: $b} else {} end)
     + (if $n != "" then {notes: $n} else {} end)')" || exit $?
  gg_http_or_die "settlement create" POST "${base}/v1/admin/settlement" --token "$admin_token" --json "$body"
}

# gg_settlement_create_batch <periodFrom> <periodTo> <partnerId[:branchId]> [...]
gg_settlement_create_batch() {
  local period_from="$1" period_to="$2"; shift 2
  local base admin_token targets body
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  targets="$(_gg_settlement_targets "$@")" || exit $?
  body="$(jq -n --arg f "$period_from" --arg t "$period_to" --argjson targets "$targets" \
    '{periodFrom: $f, periodTo: $t, targets: $targets}')" || exit $?
  gg_http_or_die "settlement batch create" POST "${base}/v1/admin/settlement/batch" --token "$admin_token" --json "$body"
}

gg_settlement_get() {
  local settlement_id="$1"
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  gg_http_or_die "settlement get" GET "${base}/v1/admin/settlement/${settlement_id}" --token "$admin_token"
}

# gg_settlement_mark_settled <settlementId> [notes]
gg_settlement_mark_settled() {
  local settlement_id="$1" notes="${2:-}"
  local base admin_token body
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  body="$(jq -n --arg n "$notes" '{notes: $n}')" || exit $?
  gg_http_or_die "settlement mark-settled" PUT "${base}/v1/admin/settlement/${settlement_id}/mark-settled" --token "$admin_token" --json "$body"
}

# --- Admin WABA Flows (/v1/admin/waba/flows) ---
#
# `manageFlows` is deliberately excluded from the wabaMiddleware API-key role in
# src/config/roles.ts (only super-admin has it) — unlike every sibling admin/waba/* route, these
# calls use gg_admin_token (admin bearer), NOT an X-Api-Key header, even though the route itself
# accepts either via authJwtOrApiKey.

# gg_waba_flow_definitions_list [key=value ...] — optional query filters: key, sortBy, limit, page.
gg_waba_flow_definitions_list() {
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  local -a query_args=()
  local kv
  for kv in "$@"; do
    query_args+=(--query "$kv")
  done
  gg_http_or_die "waba flow definitions list" GET "${base}/v1/admin/waba/flows/definitions" --token "$admin_token" "${query_args[@]}"
}

# gg_waba_flow_definition_create <key> <name> <categories-csv> <flowJson> [autoProvision]
# categories-csv: comma-separated values from WABA_FLOW_CATEGORIES (e.g. "SIGN_UP,CONTACT_US").
# autoProvision: pass "true" or "false" (a JSON boolean literal), or omit.
gg_waba_flow_definition_create() {
  local key="$1" name="$2" categories_csv="$3" flow_json="$4" auto_provision="${5:-}"
  local base admin_token categories_json body
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  categories_json="$(jq -nc --arg csv "$categories_csv" '$csv | split(",")')" || exit $?
  if [ -n "$auto_provision" ]; then
    body="$(jq -n --arg k "$key" --arg n "$name" --argjson cats "$categories_json" --arg fj "$flow_json" --argjson ap "$auto_provision" \
      '{key: $k, name: $n, categories: $cats, flowJson: $fj, autoProvision: $ap}')" || exit $?
  else
    body="$(jq -n --arg k "$key" --arg n "$name" --argjson cats "$categories_json" --arg fj "$flow_json" \
      '{key: $k, name: $n, categories: $cats, flowJson: $fj}')" || exit $?
  fi
  gg_http_or_die "waba flow definition create" POST "${base}/v1/admin/waba/flows/definitions" --token "$admin_token" --json "$body"
}

gg_waba_flow_definition_get() {
  local definition_id="$1"
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  gg_http_or_die "waba flow definition get" GET "${base}/v1/admin/waba/flows/definitions/${definition_id}" --token "$admin_token"
}

# gg_waba_flow_definition_update <definitionId> [name] [categories-csv] [flowJson] [autoProvision]
# — pass "" for any field that should stay unset.
gg_waba_flow_definition_update() {
  local definition_id="$1" name="${2:-}" categories_csv="${3:-}" flow_json="${4:-}" auto_provision="${5:-}"
  local base admin_token body="{}"
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  [ -n "$name" ] && { body="$(jq --arg n "$name" '. + {name: $n}' <<< "$body")" || exit $?; }
  if [ -n "$categories_csv" ]; then
    local categories_json
    categories_json="$(jq -nc --arg csv "$categories_csv" '$csv | split(",")')" || exit $?
    body="$(jq --argjson cats "$categories_json" '. + {categories: $cats}' <<< "$body")" || exit $?
  fi
  [ -n "$flow_json" ] && { body="$(jq --arg fj "$flow_json" '. + {flowJson: $fj}' <<< "$body")" || exit $?; }
  [ -n "$auto_provision" ] && { body="$(jq --argjson ap "$auto_provision" '. + {autoProvision: $ap}' <<< "$body")" || exit $?; }
  gg_http_or_die "waba flow definition update" PATCH "${base}/v1/admin/waba/flows/definitions/${definition_id}" --token "$admin_token" --json "$body"
}

gg_waba_flow_definition_release() {
  local definition_id="$1"
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  gg_http_or_die "waba flow definition release" POST "${base}/v1/admin/waba/flows/definitions/${definition_id}/release" --token "$admin_token"
}

# gg_waba_flow_deployments_list [key=value ...] — optional query filters: wabaId, key, sortBy,
# limit, page.
gg_waba_flow_deployments_list() {
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  local -a query_args=()
  local kv
  for kv in "$@"; do
    query_args+=(--query "$kv")
  done
  gg_http_or_die "waba flow deployments list" GET "${base}/v1/admin/waba/flows/deployments" --token "$admin_token" "${query_args[@]}"
}

gg_waba_flow_deployment_retry() {
  local deployment_id="$1"
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  gg_http_or_die "waba flow deployment retry" POST "${base}/v1/admin/waba/flows/deployments/${deployment_id}/retry" --token "$admin_token"
}

gg_waba_flow_deployment_deprecate() {
  local deployment_id="$1"
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  gg_http_or_die "waba flow deployment deprecate" POST "${base}/v1/admin/waba/flows/deployments/${deployment_id}/deprecate" --token "$admin_token"
}

# --- Admin Genie (/v1/admin/genie) ---
#
# threadId is a composite "diner-agent:<cartId>:<dinerId>" (see buildThreadId in
# src/modules/genieV2/genie.helpers.ts) — build it yourself from a spawned session's cartId and
# dinerId before calling any thread-scoped function below. Colons in a URL path segment pass
# through curl unencoded without trouble, so no manual encoding is done here.

gg_genie_fleet() {
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  gg_http_or_die "genie fleet" GET "${base}/v1/admin/genie/fleet" --token "$admin_token"
}

# gg_genie_sessions [page] [limit] [fromTimestamp] [toTimestamp] — pass "" to skip a field.
gg_genie_sessions() {
  local page="${1:-}" limit="${2:-}" from_ts="${3:-}" to_ts="${4:-}"
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  local -a query_args=()
  [ -n "$page" ] && query_args+=(--query "page=${page}")
  [ -n "$limit" ] && query_args+=(--query "limit=${limit}")
  [ -n "$from_ts" ] && query_args+=(--query "fromTimestamp=${from_ts}")
  [ -n "$to_ts" ] && query_args+=(--query "toTimestamp=${to_ts}")
  gg_http_or_die "genie sessions" GET "${base}/v1/admin/genie/sessions" --token "$admin_token" "${query_args[@]}"
}

gg_genie_thread_get() {
  local thread_id="$1"
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  gg_http_or_die "genie thread get" GET "${base}/v1/admin/genie/threads/${thread_id}" --token "$admin_token"
}

# gg_genie_thread_activity <threadId> [limit]
gg_genie_thread_activity() {
  local thread_id="$1" limit="${2:-}"
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  if [ -n "$limit" ]; then
    gg_http_or_die "genie thread activity" GET "${base}/v1/admin/genie/threads/${thread_id}/activity" --token "$admin_token" --query "limit=${limit}"
  else
    gg_http_or_die "genie thread activity" GET "${base}/v1/admin/genie/threads/${thread_id}/activity" --token "$admin_token"
  fi
}

gg_genie_thread_evict() {
  local thread_id="$1"
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  gg_http_or_die "genie thread evict" DELETE "${base}/v1/admin/genie/threads/${thread_id}" --token "$admin_token"
}

# gg_genie_thread_signal <threadId> <type> [payloadJson] — validation only requires `signal` to
# be an object; {type, payload} mirrors the ParsedBehaviorSignal shape genie.helpers expects.
gg_genie_thread_signal() {
  local thread_id="$1" signal_type="$2" payload_json="${3:-}"
  [ -z "$payload_json" ] && payload_json='{}'
  local base admin_token body
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  body="$(jq -n --arg t "$signal_type" --argjson p "$payload_json" '{signal: {type: $t, payload: $p}}')" || exit $?
  gg_http_or_die "genie thread signal" POST "${base}/v1/admin/genie/threads/${thread_id}/signal" --token "$admin_token" --json "$body"
}

gg_genie_thread_chat() {
  local thread_id="$1" message="$2"
  local base admin_token body
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  body="$(jq -n --arg m "$message" '{message: $m}')" || exit $?
  gg_http_or_die "genie thread chat" POST "${base}/v1/admin/genie/threads/${thread_id}/chat" --token "$admin_token" --json "$body"
}

gg_genie_thread_end() {
  local thread_id="$1"
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  gg_http_or_die "genie thread end" POST "${base}/v1/admin/genie/threads/${thread_id}/end" --token "$admin_token"
}

# gg_genie_spawn <dinerId> <cartId> <branchId> <accountId> <partnerId> <tableId> — all six fields
# are required by validation, even though some look optional at a glance.
gg_genie_spawn() {
  local diner_id="$1" cart_id="$2" branch_id="$3" account_id="$4" partner_id="$5" table_id="$6"
  local base admin_token body
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  body="$(jq -n --arg d "$diner_id" --arg c "$cart_id" --arg br "$branch_id" --arg a "$account_id" --arg p "$partner_id" --arg tb "$table_id" \
    '{dinerId: $d, cartId: $c, branchId: $br, accountId: $a, partnerId: $p, tableId: $tb}')" || exit $?
  gg_http_or_die "genie spawn" POST "${base}/v1/admin/genie/spawn" --token "$admin_token" --json "$body"
}

# --- Admin Dashboard (/v1/admin/dashboard) ---

gg_dashboard_summary() {
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  gg_http_or_die "dashboard summary" GET "${base}/v1/admin/dashboard/summary" --token "$admin_token"
}

# gg_dashboard_timeseries <metric> <interval> [from] [to]
# metric: orders|signups|partners|revenue   interval: day|week
gg_dashboard_timeseries() {
  local metric="$1" interval="$2" from="${3:-}" to="${4:-}"
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  local -a query_args=(--query "metric=${metric}" --query "interval=${interval}")
  [ -n "$from" ] && query_args+=(--query "from=${from}")
  [ -n "$to" ] && query_args+=(--query "to=${to}")
  gg_http_or_die "dashboard timeseries" GET "${base}/v1/admin/dashboard/timeseries" --token "$admin_token" "${query_args[@]}"
}

# gg_dashboard_top <metric> [limit]
# metric: partners-by-orders|diners-by-orders|dishes|cuisines|partners-by-revenue
gg_dashboard_top() {
  local metric="$1" limit="${2:-}"
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  if [ -n "$limit" ]; then
    gg_http_or_die "dashboard top" GET "${base}/v1/admin/dashboard/top" --token "$admin_token" --query "metric=${metric}" --query "limit=${limit}"
  else
    gg_http_or_die "dashboard top" GET "${base}/v1/admin/dashboard/top" --token "$admin_token" --query "metric=${metric}"
  fi
}

# --- Admin Partner Mgmt (/v1/admin/partner) ---

# gg_partner_list [key=value ...] — optional query filters: page, limit, sortBy, status, plan,
# search.
gg_partner_list() {
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  local -a query_args=()
  local kv
  for kv in "$@"; do
    query_args+=(--query "$kv")
  done
  gg_http_or_die "partner list" GET "${base}/v1/admin/partner" --token "$admin_token" "${query_args[@]}"
}

gg_partner_get() {
  local account_id="$1"
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  gg_http_or_die "partner get" GET "${base}/v1/admin/partner/${account_id}" --token "$admin_token"
}

# gg_partner_patch <accountId> <key=value> [key=value ...] — free-form $set; the route has no
# body validation, so any field name is accepted as-is. Values are sent as strings (gg_json_obj),
# which covers the common admin tweaks (name, customDomain, etc.) but not boolean/numeric fields.
gg_partner_patch() {
  local account_id="$1"; shift
  local base admin_token body
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  local -a obj_args=()
  local kv
  for kv in "$@"; do
    obj_args+=("${kv%%=*}" "${kv#*=}")
  done
  body="$(gg_json_obj "${obj_args[@]}")" || exit $?
  gg_http_or_die "partner patch" PATCH "${base}/v1/admin/partner/${account_id}" --token "$admin_token" --json "$body"
}

gg_partner_agent_contexts() {
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  gg_http_or_die "partner agent contexts" GET "${base}/v1/admin/partner/agent-contexts" --token "$admin_token"
}

gg_partner_branch_contexts() {
  local account_id="$1"
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  gg_http_or_die "partner branch contexts" GET "${base}/v1/admin/partner/${account_id}/branches/agent-context" --token "$admin_token"
}

gg_partner_branch_context_get() {
  local account_id="$1" branch_id="$2"
  local base admin_token
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  gg_http_or_die "partner branch context get" GET "${base}/v1/admin/partner/${account_id}/branches/${branch_id}/agent-context" --token "$admin_token"
}

# gg_partner_branch_context_put <accountId> <branchId> <context>
gg_partner_branch_context_put() {
  local account_id="$1" branch_id="$2" context="$3"
  local base admin_token body
  base="$(gg_session_get base)" || exit $?
  admin_token="$(gg_admin_token)" || exit $?
  body="$(jq -n --arg c "$context" '{context: $c}')" || exit $?
  gg_http_or_die "partner branch context put" PUT "${base}/v1/admin/partner/${account_id}/branches/${branch_id}/agent-context" --token "$admin_token" --json "$body"
}
