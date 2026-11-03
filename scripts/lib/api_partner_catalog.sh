#!/usr/bin/env bash
# Partner catalog management domain verbs — Combo CRUD, Menu bulk edit/delete/duplicate, partner
# Settlement reads. Expressed over http.sh + json.sh, exactly like api.sh. Intended to be sourced
# by bootstrap.sh once wired in centrally; until then, menu_manage.sh / partner_settlement.sh
# source it directly, right after lib/bootstrap.sh.
#
# IMPORTANT: every `var="$(some_function ...)"` line below is followed by `|| exit $?` — see the
# header comment in api.sh for why this is load-bearing, not defensive style. Any new function
# added to this file must follow the same pattern.

[ "${BASH_SOURCE[0]}" = "$0" ] && { echo "lib/api_partner_catalog.sh is a library — source it, don't execute it." >&2; exit 1; }

# --- Combo CRUD (/v1/partner/combo) ---
#
# createCombo's body REQUIRES foodCategoryId and foodTypeId (comboValidation.createCombo) —
# api_reference.md's older "Combo Fetching" doc example omits both, which would 400 live against
# the current validation. gg_combo_create below matches the real schema.

# gg_combo_create <comboName> <foodCategoryId> <foodTypeId> <menuItemId> <quantity> [dPrice] —
# single-item combo (the common smoke-test shape). For a multi-item combo, build the body
# yourself per the raw curl example in api_reference.md.
gg_combo_create() {
  local combo_name="$1" food_category_id="$2" food_type_id="$3" menu_item_id="$4" quantity="$5" d_price="${6:-}"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  body="$(jq -n \
    --arg comboName "$combo_name" --arg foodCategoryId "$food_category_id" --arg foodTypeId "$food_type_id" \
    --arg menuItemId "$menu_item_id" --argjson quantity "$quantity" --arg dPrice "$d_price" \
    '{comboName: $comboName, foodCategoryId: $foodCategoryId, foodTypeId: $foodTypeId,
      items: [{menuItemId: $menuItemId, quantity: $quantity}]}
     + (if $dPrice != "" then {dPrice: ($dPrice | tonumber)} else {} end)')" || exit $?
  gg_http_or_die "combo create" POST "${base}/v1/partner/combo" --token "$partner_token" --json "$body"
}

gg_combo_get() {
  local combo_id="$1"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "combo get" GET "${base}/v1/partner/combo/${combo_id}" --token "$partner_token"
}

# gg_combo_update <comboId> [comboName] [isActive] — isActive is the literal string "true" or
# "false"; pass "" to omit a field. Matches api_reference.md's documented `{"isActive":false}`
# update example, plus comboName for renaming.
gg_combo_update() {
  local combo_id="$1" combo_name="${2:-}" is_active="${3:-}"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  body="$(jq -n --arg comboName "$combo_name" --arg isActive "$is_active" \
    '{}
     + (if $comboName != "" then {comboName: $comboName} else {} end)
     + (if $isActive != "" then {isActive: ($isActive == "true")} else {} end)')" || exit $?
  gg_http_or_die "combo update" PATCH "${base}/v1/partner/combo/${combo_id}" --token "$partner_token" --json "$body"
}

gg_combo_delete() {
  local combo_id="$1"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "combo delete" DELETE "${base}/v1/partner/combo/${combo_id}" --token "$partner_token"
}

# --- Menu bulk/duplicate (/v1/partner/menu) ---

# gg_menu_bulk_edit <idsCsv> <changesJson> [customizationMode] — idsCsv is comma-separated
# menuItemIds (e.g. "id1,id2"). changesJson is a raw JSON object matching
# menuItemValidation.bulkEditMenuItems' `changes` shape (e.g. '{"chefsChoice":true}') — its
# fields are too numerous/nested to flatten into positional args, so it is passed through as-is.
gg_menu_bulk_edit() {
  local ids_csv="$1" changes_json="$2" customization_mode="${3:-}"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  body="$(jq -n --arg idsCsv "$ids_csv" --argjson changes "$changes_json" --arg customizationMode "$customization_mode" \
    '{ids: ($idsCsv | split(",")), changes: $changes}
     + (if $customizationMode != "" then {customizationMode: $customizationMode} else {} end)')" || exit $?
  gg_http_or_die "menu bulk edit" PUT "${base}/v1/partner/menu/bulk" --token "$partner_token" --json "$body"
}

# gg_menu_bulk_delete <idsCsv> — idsCsv is comma-separated menuItemIds.
gg_menu_bulk_delete() {
  local ids_csv="$1"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  body="$(jq -n --arg idsCsv "$ids_csv" '{ids: ($idsCsv | split(","))}')" || exit $?
  gg_http_or_die "menu bulk delete" DELETE "${base}/v1/partner/menu/bulk" --token "$partner_token" --json "$body"
}

# gg_menu_duplicate <menuItemId> <foodCategoryId>
gg_menu_duplicate() {
  local menu_item_id="$1" food_category_id="$2"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  body="$(jq -n --arg foodCategoryId "$food_category_id" '{foodCategoryId: $foodCategoryId}')" || exit $?
  gg_http_or_die "menu duplicate" POST "${base}/v1/partner/menu/${menu_item_id}/duplicate" --token "$partner_token" --json "$body"
}

# --- Partner Settlement (/v1/partner/settlement, read-only) ---

# gg_partner_settlement_list [k=v ...] — any number of listPartnerSettlements query filters (branchId,
# status, gateway, periodFrom, periodTo, sortBy, page, limit), passed through verbatim as
# --query entries. branchId is auto-scoped server-side for non-admin partner users, so it's
# rarely needed here.
gg_partner_settlement_list() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?

  local -a query_args=()
  local kv
  for kv in "$@"; do
    query_args+=(--query "$kv")
  done
  gg_http_or_die "settlement list" GET "${base}/v1/partner/settlement" --token "$partner_token" "${query_args[@]}"
}

gg_partner_settlement_summary() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "settlement summary" GET "${base}/v1/partner/settlement/summary" --token "$partner_token"
}
