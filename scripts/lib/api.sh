#!/usr/bin/env bash
# GrubGenie domain verbs, expressed over http.sh + json.sh. No raw curl here — that's the whole
# point: http.sh knows nothing about carts, this file knows nothing about curl. Sourced by
# bootstrap.sh.
#
# IMPORTANT: every `var="$(some_function ...)"` line below is followed by `|| exit $?`. This is
# not defensive style — it's load-bearing. Bash's `set -e` does NOT reliably auto-abort when a
# command substitution's inner command is itself a function that calls `exit` two or more levels
# of `$(...)` nesting deep (confirmed on bash 3.2, the default /bin/bash on macOS — no
# `inherit_errexit` shopt exists there to fix it). Without the explicit `|| exit $?`, a failed
# gg_session_get/gg_http_or_die call here silently falls through with an empty variable instead
# of aborting. Any new function added to this file must follow the same pattern. Only each
# function's LAST command (its own return value) is exempt — that single level propagates
# correctly on its own, exactly like gg_http_or_die's internal `body="$(gg_http ...)" || rc=$?`.

[ "${BASH_SOURCE[0]}" = "$0" ] && { echo "lib/api.sh is a library — source it, don't execute it." >&2; exit 1; }

gg_cart_create() {
  local base table_id diner_token resp body
  base="$(gg_session_get base)" || exit $?
  table_id="$(gg_session_get tableId)" || exit $?
  diner_token="$(gg_session_get dinerToken)" || exit $?

  body="$(jq -n --arg tableId "$table_id" '{tableId: $tableId}')" || exit $?
  resp="$(gg_http_or_die "cart create" POST "${base}/v1/genie/cart" --token "$diner_token" --json "$body")" || exit $?
  gg_json_field "$resp" '.result.cartId' "cartId"
}

# gg_order_create <cart_id> <line_key> <line_id> [qty] — line_key ∈ itemId | comboId.
# Prints the orderId. Replaces the item/combo script split: the two scripts differed only by
# this key, so it's now data, not a file (OCP — a future variant/offer type needs no new script).
gg_order_create() {
  local cart_id="$1" line_key="$2" line_id="$3" qty="${4:-1}"
  local base diner_token diner_id resp body
  base="$(gg_session_get base)" || exit $?
  diner_token="$(gg_session_get dinerToken)" || exit $?
  diner_id="$(gg_session_get dinerId)" || exit $?

  body="$(jq -n --arg k "$line_key" --arg v "$line_id" --argjson q "$qty" \
    '{items: [{($k): $v, quantity: $q}]}')" || exit $?
  resp="$(gg_http_or_die "order create" POST "${base}/v1/genie/order" \
    --token "$diner_token" --json "$body" \
    --query "cartId=${cart_id}" --query "dinerId=${diner_id}")" || exit $?
  gg_json_field "$resp" '.result.currentActiveOrder' "orderId"
}

# gg_order_place <cart_id> <order_id> → prints the place-order response message.
gg_order_place() {
  local cart_id="$1" order_id="$2"
  local base diner_token resp
  base="$(gg_session_get base)" || exit $?
  diner_token="$(gg_session_get dinerToken)" || exit $?

  resp="$(gg_http_or_die "place order" PUT "${base}/v1/genie/order/place-order/${order_id}" \
    --token "$diner_token" --query "cartId=${cart_id}")" || exit $?
  gg_json_message "$resp"
}

# gg_order_respond <order_id> accept|reject → prints the response message. Requires a partner
# session (this is the merchant side approving/rejecting a manually-accepted order).
gg_order_respond() {
  local order_id="$1" action="$2"
  local base partner_token resp body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  body="$(jq -n --arg action "$action" '{action: $action}')" || exit $?
  resp="$(gg_http_or_die "order $action" PATCH "${base}/v1/partner/order-history/respond/${order_id}" \
    --token "$partner_token" --json "$body")" || exit $?
  gg_json_message "$resp"
}

# gg_pay_in_person <cart_id> → prints the response message.
gg_pay_in_person() {
  local cart_id="$1"
  local base diner_token diner_id resp body
  base="$(gg_session_get base)" || exit $?
  diner_token="$(gg_session_get dinerToken)" || exit $?
  diner_id="$(gg_session_get dinerId)" || exit $?

  body="$(jq -n --arg dinerId "$diner_id" '{dinerId: $dinerId}')" || exit $?
  resp="$(gg_http_or_die "pay in person" POST "${base}/v1/genie/cart/${cart_id}/payment/pay-in-person" \
    --token "$diner_token" --json "$body")" || exit $?
  gg_json_message "$resp"
}

# gg_payment_confirm <cart_id> → partner confirms a cash payment. Prints the response message.
gg_payment_confirm() {
  local cart_id="$1"
  local base partner_token resp body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  body="$(jq -n '{paymentStatus: "done", paymentMode: "cash", confirmed: true}')" || exit $?
  resp="$(gg_http_or_die "confirm payment" PUT "${base}/v1/partner/order-history/update-payment-status/${cart_id}" \
    --token "$partner_token" --json "$body")" || exit $?
  gg_json_message "$resp"
}

gg_tables_list() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "table list" GET "${base}/v1/partner/table" --token "$partner_token"
}

# gg_table_set_status <table_id> [status] → prints the response message.
gg_table_set_status() {
  local table_id="$1" status="${2:-available}"
  local base partner_token resp body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  body="$(jq -n --arg status "$status" '{status: $status, confirmed: true}')" || exit $?
  resp="$(gg_http_or_die "table status" PUT "${base}/v1/partner/table/table-status/${table_id}" \
    --token "$partner_token" --json "$body")" || exit $?
  gg_json_message "$resp"
}

# --- Petpooja POS ---

gg_pos_menu() {
  local provider="${1:-$GG_POS_PROVIDER}"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "pos menu" GET "${base}/v1/partner/pos/menu" --token "$partner_token" \
    --query "provider=${provider}"
}

gg_pos_items() {
  local provider="${1:-$GG_POS_PROVIDER}"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "pos items" GET "${base}/v1/partner/pos/${provider}/items" --token "$partner_token"
}

# gg_pos_sync [provider] → prints the raw response. 202 (enqueued) and 409 (already running) are
# both treated as success here — a 409 means the sync this call wanted is already in flight,
# which is the caller's desired end state, not a failure.
gg_pos_sync() {
  local provider="${1:-$GG_POS_PROVIDER}"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  body="$(gg_json_obj provider "$provider")" || exit $?
  gg_http_or_die "pos sync" POST "${base}/v1/partner/pos/sync-menu" --token "$partner_token" --json "$body" --expect '2xx,409'
}

gg_pos_config_get() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "pos config get" GET "${base}/v1/partner/branch/pos-config" --token "$partner_token"
}

# gg_pos_config_setup — requires GG_PETPOOJA_APP_SECRET / GG_PETPOOJA_ACCESS_TOKEN
# (scripts/config/credentials.env). appKey/restId are public fixtures from constants.sh.
gg_pos_config_setup() {
  gg_load_credentials
  gg_require "${GG_PETPOOJA_APP_SECRET:-}" "GG_PETPOOJA_APP_SECRET not set — see scripts/config/credentials.example.env"
  gg_require "${GG_PETPOOJA_ACCESS_TOKEN:-}" "GG_PETPOOJA_ACCESS_TOKEN not set — see scripts/config/credentials.example.env"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  body="$(jq -n \
    --arg provider "$GG_POS_PROVIDER" \
    --arg appKey "$GG_POS_APP_KEY" \
    --arg appSecret "$GG_PETPOOJA_APP_SECRET" \
    --arg accessToken "$GG_PETPOOJA_ACCESS_TOKEN" \
    --arg restId "$GG_POS_REST_ID" \
    '{provider: $provider, isEnabled: true,
      credentials: {appKey: $appKey, appSecret: $appSecret, accessToken: $accessToken, restId: $restId}}')" || exit $?
  gg_http_or_die "pos config setup" PUT "${base}/v1/partner/branch/pos-config" --token "$partner_token" --json "$body"
}

gg_pos_config_disable() {
  local provider="${1:-$GG_POS_PROVIDER}"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "pos config disable" DELETE "${base}/v1/partner/branch/pos-config/${provider}" --token "$partner_token"
}
