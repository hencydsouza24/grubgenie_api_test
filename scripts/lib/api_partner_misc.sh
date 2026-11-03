#!/usr/bin/env bash
# Staff-assisted ordering, reservation widget + public reservation, front-desk report, WhatsApp
# agent settings/audience segments, order-history active-by-table, and diner genie extensions.
# Several small mixed-auth domains in one file by design (each added for the same update pass) —
# every function below states its own auth explicitly; don't assume a shared token across them.
#
# Not yet wired into lib/bootstrap.sh (central integration pass handles that, to avoid collisions
# with other concurrent additions) — scripts using this file source it directly, after bootstrap.sh:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.sh"
#   source "$GG_LIB_DIR/api_partner_misc.sh"
#
# IMPORTANT: every `var="$(some_function ...)"` line below is followed by `|| exit $?` — see
# api.sh's header comment for why this is load-bearing, not defensive style.

[ "${BASH_SOURCE[0]}" = "$0" ] && { echo "lib/api_partner_misc.sh is a library — source it, don't execute it." >&2; exit 1; }

# --- Staff Order (partner bearer; waiter/captain acting on behalf of a diner/table) ---
#
# Confirmed from src/routes/v1/partner/order.route.ts + staffOrder.controller.ts: this is its OWN
# route file (mounted at /v1/partner/order), not a reuse of the diner-facing /v1/genie/cart +
# /v1/genie/order routes under a different token. It reuses the same WRITE PATHS internally
# (orderService.createOrderInTransaction/updateOrder/placeOrder) but has distinct URLs.

# gg_staff_cart_create <table_id> → prints cartId. POST .../table/:tableId/cart takes no body;
# the response IS the raw cart doc (unlike the diner-facing gg_cart_create, which gets a custom
# {cartId,...} wrapper) — so the id is `.result._id`, not `.result.cartId`.
gg_staff_cart_create() {
  local table_id="$1"
  local base partner_token resp
  gg_require "$table_id" "gg_staff_cart_create: tableId required"
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  resp="$(gg_http_or_die "staff cart create" POST "${base}/v1/partner/order/table/${table_id}/cart" \
    --token "$partner_token")" || exit $?
  gg_json_field "$resp" '.result._id' "cartId"
}

# gg_staff_order_create <cart_id> <line_key> <line_id> [qty] — lineKey ∈ itemId | comboId.
# Prints the orderId. The cart-with-orders response carries it as `.result.currentActiveOrder`,
# the same field the diner-facing gg_order_create reads off the diner cart response.
gg_staff_order_create() {
  local cart_id="$1" line_key="$2" line_id="$3" qty="${4:-1}"
  local base partner_token resp body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  body="$(jq -n --arg k "$line_key" --arg v "$line_id" --argjson q "$qty" \
    '{items: [{($k): $v, quantity: $q}]}')" || exit $?
  resp="$(gg_http_or_die "staff order create" POST "${base}/v1/partner/order/cart/${cart_id}/items" \
    --token "$partner_token" --json "$body")" || exit $?
  gg_json_field "$resp" '.result.currentActiveOrder' "orderId"
}

# gg_staff_order_update <order_id> <cart_id> <line_key> <line_id> [qty] — merges one more item
# onto an existing order (the API replaces the whole item list, but the controller itself merges
# new items onto the order's current ones). Prints the raw cart-with-orders response.
gg_staff_order_update() {
  local order_id="$1" cart_id="$2" line_key="$3" line_id="$4" qty="${5:-1}"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  body="$(jq -n --arg k "$line_key" --arg v "$line_id" --argjson q "$qty" \
    '{items: [{($k): $v, quantity: $q}]}')" || exit $?
  gg_http_or_die "staff order update" PUT "${base}/v1/partner/order/order/${order_id}/items" \
    --token "$partner_token" --json "$body" --query "cartId=${cart_id}"
}

# gg_staff_order_place <order_id> <cart_id> → prints {"message","status"}. Same extraction as the
# diner-facing gg_order_place: status comes from `.result.orders[]`, never parsed out of `.message`.
gg_staff_order_place() {
  local order_id="$1" cart_id="$2"
  local base partner_token resp message status
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  resp="$(gg_http_or_die "staff place order" PUT "${base}/v1/partner/order/order/${order_id}/place" \
    --token "$partner_token" --query "cartId=${cart_id}")" || exit $?

  message="$(gg_json_message "$resp")"
  status="$(printf '%s' "$resp" | jq -r --arg id "$order_id" \
    '.result.orders[]? | select(._id == $id) | .orderStatus // empty')"

  jq -n --arg message "$message" --arg status "${status:-unknown}" '{message: $message, status: $status}'
}

# --- Reservation Widget Embed (X-Api-Key auth — NOT partner bearer) ---
#
# Confirmed from reservationWidget.route.ts: GET /embed uses authJwtOrApiKey, which also accepts
# a Bearer JWT, but the embed script's real caller (the restaurant's public website) only ever
# has the widget's own API key, so that's what this function uses.

# gg_reservation_widget_embed — requires GG_WIDGET_EMBED_KEY (scripts/config/credentials.env).
gg_reservation_widget_embed() {
  gg_load_credentials
  gg_require "${GG_WIDGET_EMBED_KEY:-}" "GG_WIDGET_EMBED_KEY not set — see scripts/config/credentials.example.env"
  local base
  base="$(gg_resolve_base)" || exit $?
  gg_http_or_die "reservation widget embed" GET "${base}/v1/partner/reservation-widget/embed" \
    --header "X-Api-Key: ${GG_WIDGET_EMBED_KEY}"
}

# --- Public Reservation (no auth — the signed `ref` token, format `xxx.yyy`, is the credential) ---
#
# Confirmed from src/routes/v1/genie/reservation.route.ts: genuinely no auth middleware, only rate
# limiters. gg_resolve_base is used directly (not gg_session_get base) so calling these never
# forces an unrelated partner+diner auth handshake.

gg_reservation_public_get() {
  local ref="$1" base
  gg_require "$ref" "gg_reservation_public_get: ref required"
  base="$(gg_resolve_base)" || exit $?
  gg_http_or_die "public reservation get" GET "${base}/v1/genie/reservation/${ref}"
}

# gg_reservation_public_review <ref> — the "Leave a review" redirect; curl -L (already in
# gg_http) follows it, so this returns whatever the final review-platform page serves.
gg_reservation_public_review() {
  local ref="$1" base
  gg_require "$ref" "gg_reservation_public_review: ref required"
  base="$(gg_resolve_base)" || exit $?
  gg_http_or_die "public reservation review redirect" GET "${base}/v1/genie/reservation/review/${ref}"
}

gg_reservation_public_availability() {
  local ref="$1" date="$2" party_size="$3"
  local base
  gg_require "$ref" "gg_reservation_public_availability: ref required"
  gg_require "$date" "gg_reservation_public_availability: date required (YYYY-MM-DD)"
  gg_require "$party_size" "gg_reservation_public_availability: partySize required"
  base="$(gg_resolve_base)" || exit $?
  gg_http_or_die "public reservation availability" GET "${base}/v1/genie/reservation/${ref}/availability" \
    --query "date=${date}" --query "partySize=${party_size}"
}

# gg_reservation_public_modify <ref> [startAt] [partySize] — body needs at least one of the two
# (the API's own Joi schema is `.min(1)`); this mirrors that instead of always sending both.
gg_reservation_public_modify() {
  local ref="$1" start_at="${2:-}" party_size="${3:-}"
  local base body
  gg_require "$ref" "gg_reservation_public_modify: ref required"
  if [ -z "$start_at" ] && [ -z "$party_size" ]; then
    gg_die "$GG_EXIT_USAGE" "gg_reservation_public_modify: at least one of startAt/partySize required"
  fi
  base="$(gg_resolve_base)" || exit $?
  if [ -n "$start_at" ] && [ -n "$party_size" ]; then
    body="$(jq -n --arg startAt "$start_at" --argjson partySize "$party_size" \
      '{startAt: $startAt, partySize: $partySize}')" || exit $?
  elif [ -n "$start_at" ]; then
    body="$(jq -n --arg startAt "$start_at" '{startAt: $startAt}')" || exit $?
  else
    body="$(jq -n --argjson partySize "$party_size" '{partySize: $partySize}')" || exit $?
  fi
  gg_http_or_die "public reservation modify" PATCH "${base}/v1/genie/reservation/${ref}" --json "$body"
}

# gg_reservation_public_cancel <ref> [reason] — cancel is its own endpoint, not folded into modify.
gg_reservation_public_cancel() {
  local ref="$1" reason="${2:-}"
  local base body
  gg_require "$ref" "gg_reservation_public_cancel: ref required"
  base="$(gg_resolve_base)" || exit $?
  body="$(jq -n --arg reason "$reason" '{reason: $reason}')" || exit $?
  gg_http_or_die "public reservation cancel" POST "${base}/v1/genie/reservation/${ref}/cancel" --json "$body"
}

# --- Front Desk Report (partner bearer; its own route file/controller, distinct from insights.route.ts) ---

gg_front_desk_report() {
  local from="$1" to="$2" scope="${3:-single}" branch_id="${4:-}"
  local base partner_token
  gg_require "$from" "gg_front_desk_report: from required (YYYY-MM-DD)"
  gg_require "$to" "gg_front_desk_report: to required (YYYY-MM-DD)"
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  local -a query=(--query "from=${from}" --query "to=${to}" --query "scope=${scope}")
  [ -n "$branch_id" ] && query+=(--query "branchId=${branch_id}")
  gg_http_or_die "front desk report" GET "${base}/v1/partner/insights/front-desk" \
    --token "$partner_token" "${query[@]}"
}

# gg_front_desk_report_export <from> <to> [scope] [branchId] — prints the raw XLSX bytes to
# stdout. Redirect to a file (`> report.xlsx`); do NOT capture via `$(...)` — command substitution
# strips trailing bytes and is not binary-safe, a pre-existing limitation of gg_http_or_die's own
# `body="$(gg_http ...)"` capture that applies to any binary response, not something new here.
gg_front_desk_report_export() {
  local from="$1" to="$2" scope="${3:-single}" branch_id="${4:-}"
  local base partner_token
  gg_require "$from" "gg_front_desk_report_export: from required (YYYY-MM-DD)"
  gg_require "$to" "gg_front_desk_report_export: to required (YYYY-MM-DD)"
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  local -a query=(--query "from=${from}" --query "to=${to}" --query "scope=${scope}" --query "format=xlsx")
  [ -n "$branch_id" ] && query+=(--query "branchId=${branch_id}")
  gg_http_or_die "front desk report export" GET "${base}/v1/partner/insights/front-desk/export" \
    --token "$partner_token" "${query[@]}"
}

# --- WhatsApp Agent Settings + Audience Segments (partner bearer) ---
#
# Confirmed mount path from src/routes/v1/partner/whatsapp/index.ts: agentSettings.route.ts is
# mounted at '/agent-settings' (kebab-case), not '/agentSettings'.

gg_whatsapp_agent_settings_get() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "whatsapp agent settings get" GET "${base}/v1/partner/whatsapp/agent-settings" \
    --token "$partner_token"
}

# gg_whatsapp_agent_settings_update <field> <value> — single-field patch. The body schema accepts
# any one (or more) of ~10 optional fields with `.min(1)`; this covers the common "change one
# setting" test case instead of exposing all ten as positional params.
gg_whatsapp_agent_settings_update() {
  local field="$1" value="$2"
  local base partner_token body
  gg_require "$field" "gg_whatsapp_agent_settings_update: field required"
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  body="$(jq -n --arg k "$field" --arg v "$value" '{($k): $v}')" || exit $?
  gg_http_or_die "whatsapp agent settings update" PATCH "${base}/v1/partner/whatsapp/agent-settings" \
    --token "$partner_token" --json "$body"
}

gg_whatsapp_audience_segments() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "whatsapp audience segments" GET "${base}/v1/partner/whatsapp/campaigns/audience-segments" \
    --token "$partner_token"
}

# --- Order History: Active Order By Table (partner bearer) ---

gg_order_active_by_table() {
  local table_id="$1"
  local base partner_token
  gg_require "$table_id" "gg_order_active_by_table: tableId required"
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "active order by table" GET "${base}/v1/partner/order-history/active-by-table/${table_id}" \
    --token "$partner_token"
}

# --- Diner Extensions (diner bearer) ---

gg_combo_list() {
  local base diner_token
  base="$(gg_session_get base)" || exit $?
  diner_token="$(gg_session_get dinerToken)" || exit $?
  gg_http_or_die "combo list" GET "${base}/v1/genie/combo" --token "$diner_token"
}

gg_diner_combo_get() {
  local combo_id="$1"
  local base diner_token
  gg_require "$combo_id" "gg_diner_combo_get: comboId required"
  base="$(gg_session_get base)" || exit $?
  diner_token="$(gg_session_get dinerToken)" || exit $?
  gg_http_or_die "combo get" GET "${base}/v1/genie/combo/${combo_id}" --token "$diner_token"
}

gg_diner_order_detail() {
  local order_id="$1"
  local base diner_token
  gg_require "$order_id" "gg_diner_order_detail: orderId required"
  base="$(gg_session_get base)" || exit $?
  diner_token="$(gg_session_get dinerToken)" || exit $?
  gg_http_or_die "diner order detail" GET "${base}/v1/genie/order/${order_id}" --token "$diner_token"
}

# gg_diner_link_identity <field> <value> <code> — field is currently always "phone" (the API's
# own Joi schema only allows that one value), value must be E.164, code is the 6-digit OTP.
gg_diner_link_identity() {
  local field="$1" value="$2" code="$3"
  local base diner_token body
  gg_require "$field" "gg_diner_link_identity: field required"
  gg_require "$value" "gg_diner_link_identity: value required"
  gg_require "$code" "gg_diner_link_identity: code required"
  base="$(gg_session_get base)" || exit $?
  diner_token="$(gg_session_get dinerToken)" || exit $?
  body="$(jq -n --arg field "$field" --arg value "$value" --arg code "$code" \
    '{field: $field, value: $value, code: $code}')" || exit $?
  gg_http_or_die "diner link identity" POST "${base}/v1/genie/profile/link-identity" \
    --token "$diner_token" --json "$body"
}
