#!/usr/bin/env bash
# Partner CRM domain verbs — Guest sub-resources, Inquiry, Insights. Expressed over http.sh +
# json.sh, exactly like api.sh. Intended to be sourced by bootstrap.sh once wired in centrally;
# until then, crm.sh sources it directly, right after lib/bootstrap.sh.
#
# IMPORTANT: every `var="$(some_function ...)"` line below is followed by `|| exit $?` — see the
# header comment in api.sh for why this is load-bearing, not defensive style. Any new function
# added to this file must follow the same pattern.

[ "${BASH_SOURCE[0]}" = "$0" ] && { echo "lib/api_partner_crm.sh is a library — source it, don't execute it." >&2; exit 1; }

# --- Guest sub-resources (/v1/partner/guests/:guestId/...) ---
#
# Base Guest CRUD (list/create/get/update/delete/restore/sync-from-orders/import) predates this
# file and lives elsewhere — these are only the 5 NEW read-only sub-resources. Route base is
# `/v1/partner/guests` (plural) — confirmed against src/routes/v1/partner/index.ts, which mounts
# guest.route.ts at `/guests`, not `/guest`.

# gg_guest_whatsapp_thread <guestId> [limit] [before] — before is an ISO date string.
gg_guest_whatsapp_thread() {
  local guest_id="$1" limit="${2:-}" before="${3:-}"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  local -a query_args=()
  [ -n "$limit" ] && query_args+=(--query "limit=${limit}")
  [ -n "$before" ] && query_args+=(--query "before=${before}")
  gg_http_or_die "guest whatsapp thread" GET "${base}/v1/partner/guests/${guest_id}/whatsapp-thread" \
    --token "$partner_token" "${query_args[@]}"
}

gg_guest_campaigns() {
  local guest_id="$1"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "guest campaigns" GET "${base}/v1/partner/guests/${guest_id}/campaigns" --token "$partner_token"
}

gg_guest_inquiries() {
  local guest_id="$1"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "guest inquiries" GET "${base}/v1/partner/guests/${guest_id}/inquiries" --token "$partner_token"
}

gg_guest_calls() {
  local guest_id="$1"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "guest calls" GET "${base}/v1/partner/guests/${guest_id}/calls" --token "$partner_token"
}

gg_guest_engagement_summary() {
  local guest_id="$1"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "guest engagement summary" GET "${base}/v1/partner/guests/${guest_id}/engagement-summary" --token "$partner_token"
}

# --- Inquiry (/v1/partner/inquiry) ---

# gg_inquiry_list [k=v ...] — any number of listInquiries query filters (status, inquiryType,
# source, q, after, before, sortBy, page, limit), passed through verbatim as --query entries.
gg_inquiry_list() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  local -a query_args=()
  local kv
  for kv in "$@"; do
    query_args+=(--query "$kv")
  done
  gg_http_or_die "inquiry list" GET "${base}/v1/partner/inquiry" --token "$partner_token" "${query_args[@]}"
}

# gg_inquiry_create <guestName> <guestPhone> <inquiryType> [summary]
gg_inquiry_create() {
  local guest_name="$1" guest_phone="$2" inquiry_type="$3" summary="${4:-}"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  body="$(jq -n --arg guestName "$guest_name" --arg guestPhone "$guest_phone" \
    --arg inquiryType "$inquiry_type" --arg summary "$summary" \
    '{guestName: $guestName, guestPhone: $guestPhone, inquiryType: $inquiryType}
     + (if $summary != "" then {summary: $summary} else {} end)')" || exit $?
  gg_http_or_die "inquiry create" POST "${base}/v1/partner/inquiry" --token "$partner_token" --json "$body"
}

gg_inquiry_get() {
  local inquiry_id="$1"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "inquiry get" GET "${base}/v1/partner/inquiry/${inquiry_id}" --token "$partner_token"
}

# gg_inquiry_update <inquiryId> [guestName] [guestPhone] [inquiryType] [summary] — pass "" to
# omit a field; the API requires at least one field in the body.
gg_inquiry_update() {
  local inquiry_id="$1" guest_name="${2:-}" guest_phone="${3:-}" inquiry_type="${4:-}" summary="${5:-}"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  body="$(jq -n \
    --arg guestName "$guest_name" --arg guestPhone "$guest_phone" \
    --arg inquiryType "$inquiry_type" --arg summary "$summary" \
    '{}
     + (if $guestName != "" then {guestName: $guestName} else {} end)
     + (if $guestPhone != "" then {guestPhone: $guestPhone} else {} end)
     + (if $inquiryType != "" then {inquiryType: $inquiryType} else {} end)
     + (if $summary != "" then {summary: $summary} else {} end)')" || exit $?
  gg_http_or_die "inquiry update" PUT "${base}/v1/partner/inquiry/${inquiry_id}" --token "$partner_token" --json "$body"
}

gg_inquiry_delete() {
  local inquiry_id="$1"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "inquiry delete" DELETE "${base}/v1/partner/inquiry/${inquiry_id}" --token "$partner_token"
}

# gg_inquiry_set_status <inquiryId> <status> [reservationId] — route is
# POST /v1/partner/inquiry/:inquiryId/status (confirmed against inquiry.route.ts).
gg_inquiry_set_status() {
  local inquiry_id="$1" status="$2" reservation_id="${3:-}"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  body="$(jq -n --arg status "$status" --arg reservationId "$reservation_id" \
    '{status: $status} + (if $reservationId != "" then {reservationId: $reservationId} else {} end)')" || exit $?
  gg_http_or_die "inquiry set status" POST "${base}/v1/partner/inquiry/${inquiry_id}/status" --token "$partner_token" --json "$body"
}

# --- Insights (/v1/partner/insights) ---

# gg_insights_order_graph_data [fromDate] [toDate]
gg_insights_order_graph_data() {
  local from_date="${1:-}" to_date="${2:-}"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  local -a query_args=()
  [ -n "$from_date" ] && query_args+=(--query "fromDate=${from_date}")
  [ -n "$to_date" ] && query_args+=(--query "toDate=${to_date}")
  gg_http_or_die "insights order graph data" GET "${base}/v1/partner/insights/order-graph-data" \
    --token "$partner_token" "${query_args[@]}"
}

# gg_insights_menu_performance_details [fromDate] [toDate]
#
# NOTE: unlike every other insights endpoint, this route's controller bypasses responseHandler
# and returns {success, message, data: {summary, items}, pagination} directly — confirmed against
# src/modules/insights/insights.controller.ts. There is no top-level `.result`; callers must read
# `.data`.
gg_insights_menu_performance_details() {
  local from_date="${1:-}" to_date="${2:-}"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  local -a query_args=()
  [ -n "$from_date" ] && query_args+=(--query "fromDate=${from_date}")
  [ -n "$to_date" ] && query_args+=(--query "toDate=${to_date}")
  gg_http_or_die "insights menu performance details" GET "${base}/v1/partner/insights/menu-performance-details" \
    --token "$partner_token" "${query_args[@]}"
}

# gg_insights_category_rollup [fromDate] [toDate]
#
# NOTE: same as menu-performance-details — returns {success, message, currency, data} directly,
# not the standard {result} envelope. Callers must read `.data`.
gg_insights_category_rollup() {
  local from_date="${1:-}" to_date="${2:-}"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  local -a query_args=()
  [ -n "$from_date" ] && query_args+=(--query "fromDate=${from_date}")
  [ -n "$to_date" ] && query_args+=(--query "toDate=${to_date}")
  gg_http_or_die "insights category rollup" GET "${base}/v1/partner/insights/category-rollup" \
    --token "$partner_token" "${query_args[@]}"
}

# gg_insights_weekly <branchId> — branchId is REQUIRED by the route's own validation
# (insightValidation.getWeeklyInsights), unlike most other insights reads.
gg_insights_weekly() {
  local branch_id="$1"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "insights weekly" GET "${base}/v1/partner/insights/weekly" \
    --token "$partner_token" --query "branchId=${branch_id}"
}

# gg_insights_promote_dish <itemId> — route is
# POST /v1/partner/insights/weekly/promote-dish/:itemId, NOT /v1/partner/insights/promote-dish —
# confirmed against insights.route.ts.
gg_insights_promote_dish() {
  local item_id="$1"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "insights promote dish" POST "${base}/v1/partner/insights/weekly/promote-dish/${item_id}" --token "$partner_token"
}

# gg_insights_hourly_demand <branchId> [fromDate] [toDate] — branchId is REQUIRED.
gg_insights_hourly_demand() {
  local branch_id="$1" from_date="${2:-}" to_date="${3:-}"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  local -a query_args=(--query "branchId=${branch_id}")
  [ -n "$from_date" ] && query_args+=(--query "fromDate=${from_date}")
  [ -n "$to_date" ] && query_args+=(--query "toDate=${to_date}")
  gg_http_or_die "insights hourly demand" GET "${base}/v1/partner/insights/hourly-demand" \
    --token "$partner_token" "${query_args[@]}"
}
