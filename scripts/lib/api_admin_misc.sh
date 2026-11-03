#!/usr/bin/env bash
# Admin-bearer domain verbs for the long tail of small admin/ops endpoints: config, cuisine,
# diner, genie-core sessions, kb-topic-catalog, migration, ml, openviking, order, plan,
# qrcode-extra, waba-resolve, whatsapp-template. Expressed over http.sh + json.sh + auth.sh's
# gg_admin_token, exactly like api.sh. Sourced by bootstrap.sh.
#
# IMPORTANT: every `var="$(some_function ...)"` line below is followed by `|| exit $?` — see
# api.sh's header comment for why this is load-bearing, not defensive style. Any new function
# added to this file must follow the same pattern.

[ "${BASH_SOURCE[0]}" = "$0" ] && { echo "lib/api_admin_misc.sh is a library — source it, don't execute it." >&2; exit 1; }

# --- Config ---
# NOTE: GET /v1/admin/config/:name has NO auth() middleware in the real route (only `validate()`)
# — confirmed against src/routes/v1/admin/config.route.ts. Called here with no token; harmless if
# a token is sent, but one isn't needed.

gg_config_get() {
  local name="$1" base
  gg_require "$name" "Usage: config get <name>"
  base="$(gg_session_get base)" || exit $?
  gg_http_or_die "config get" GET "${base}/v1/admin/config/${name}"
}

# gg_config_update <name> <value> — value is sent as a plain string field, i.e. body
# `{value: "<value>"}`. The real schema's `value` is `Joi.any()` (any JSON type), but this skill's
# convention is "no shell string-interpolated JSON bodies — always jq -n --arg", so a structured
# (object/array/number) value isn't supported from the CLI here.
gg_config_update() {
  local name="$1" value="$2"
  local base token body
  gg_require "$name" "Usage: config update <name> <value>"
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  body="$(jq -n --arg value "$value" '{value: $value}')" || exit $?
  gg_http_or_die "config update" PUT "${base}/v1/admin/config/${name}" --token "$token" --json "$body"
}

gg_config_delete() {
  local name="$1" base token
  gg_require "$name" "Usage: config delete <name>"
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  gg_http_or_die "config delete" DELETE "${base}/v1/admin/config/${name}" --token "$token"
}

# --- Cuisine ---
# NOTE: both routes have NO auth() middleware in the real route (public) — confirmed against
# src/routes/v1/admin/cuisine.route.ts. Called here with no token.

gg_cuisine_list() {
  local base
  base="$(gg_session_get base)" || exit $?
  gg_http_or_die "cuisine list" GET "${base}/v1/admin/cuisine"
}

gg_cuisine_get() {
  local id="$1" base
  gg_require "$id" "Usage: cuisine get <cuisineId>"
  base="$(gg_session_get base)" || exit $?
  gg_http_or_die "cuisine get" GET "${base}/v1/admin/cuisine/${id}"
}

# --- Diner (admin) ---

gg_diner_list() {
  local page="${1:-}" limit="${2:-}"
  local base token
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  local -a query=()
  [ -n "$page" ] && query+=(--query "page=${page}")
  [ -n "$limit" ] && query+=(--query "limit=${limit}")
  # The `${query[@]+"${query[@]}"}` expansion (not a bare `"${query[@]}"`) is deliberate: under
  # `set -u` on bash 3.2 (macOS default), expanding an EMPTY array dies with "unbound variable" —
  # confirmed in sibling lib files (api_partner_voice.sh, api_partner_ops.sh) added alongside this
  # one. Bash >= 4.4 doesn't have this quirk, but 3.2 is what ships on macOS.
  gg_http_or_die "diner list" GET "${base}/v1/admin/diner" --token "$token" "${query[@]+"${query[@]}"}"
}

gg_diner_get() {
  local id="$1" base token
  gg_require "$id" "Usage: diner get <dinerId>"
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  gg_http_or_die "diner get" GET "${base}/v1/admin/diner/${id}" --token "$token"
}

# --- GenieCore sessions ---

gg_genie_core_sessions() {
  local base token
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  gg_http_or_die "genie-core sessions" GET "${base}/v1/admin/genie-core/sessions" --token "$token"
}

# --- KbTopicCatalog ---
# NOTE: mounted at /v1/admin/kb-topic-catalog (kebab-case) — confirmed against
# src/routes/v1/admin/index.ts, not /v1/admin/kbTopicCatalog.

gg_kb_topic_catalog_list() {
  local base token
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  gg_http_or_die "kb-topic-catalog list" GET "${base}/v1/admin/kb-topic-catalog" --token "$token"
}

# gg_kb_topic_catalog_create <key> <label> <store> [description] — store must be one of
# documents|menu|none (KB_TOPIC_STORES).
gg_kb_topic_catalog_create() {
  local key="$1" label="$2" store="$3" description="${4:-}"
  gg_require "$key" "Usage: kb-topic-catalog create <key> <label> <store> [description]"
  gg_require "$label" "Usage: kb-topic-catalog create <key> <label> <store> [description]"
  gg_require "$store" "Usage: kb-topic-catalog create <key> <label> <store> [description]"
  local base token body
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  body="$(jq -n --arg key "$key" --arg label "$label" --arg store "$store" --arg description "$description" \
    '{key: $key, label: $label, store: $store} + (if $description != "" then {description: $description} else {} end)')" || exit $?
  gg_http_or_die "kb-topic-catalog create" POST "${base}/v1/admin/kb-topic-catalog" --token "$token" --json "$body"
}

# gg_kb_topic_catalog_update <catalogId> [label] [description] [store] — any of label/description/
# store may be passed empty ("") to leave that field unchanged.
gg_kb_topic_catalog_update() {
  local id="$1" label="${2:-}" description="${3:-}" store="${4:-}"
  gg_require "$id" "Usage: kb-topic-catalog update <catalogId> [label] [description] [store]"
  local base token body
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  body="$(jq -n --arg label "$label" --arg description "$description" --arg store "$store" \
    '(if $label != "" then {label: $label} else {} end)
     + (if $description != "" then {description: $description} else {} end)
     + (if $store != "" then {store: $store} else {} end)')" || exit $?
  gg_http_or_die "kb-topic-catalog update" PUT "${base}/v1/admin/kb-topic-catalog/${id}" --token "$token" --json "$body"
}

gg_kb_topic_catalog_delete() {
  local id="$1" base token
  gg_require "$id" "Usage: kb-topic-catalog delete <catalogId>"
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  gg_http_or_die "kb-topic-catalog delete" DELETE "${base}/v1/admin/kb-topic-catalog/${id}" --token "$token"
}

# --- Migration ---

# gg_migration_run_all [override] — override: "true"|"false" (query param), omit for unset.
gg_migration_run_all() {
  local override="${1:-}"
  local base token
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  local -a query=()
  [ -n "$override" ] && query+=(--query "override=${override}")
  gg_http_or_die "migration run-all-pending" POST "${base}/v1/admin/migration/run-all-pending" --token "$token" "${query[@]+"${query[@]}"}"
}

# --- ML ---

gg_ml_retrain() {
  local account_id="$1" base token
  gg_require "$account_id" "Usage: ml retrain <accountId>"
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  gg_http_or_die "ml retrain" POST "${base}/v1/admin/ml/retrain/${account_id}" --token "$token"
}

# --- OpenViking (admin) ---
# body shape confirmed against src/modules/openviking/openviking.validation.ts: both routes take
# {accountId, branchId, content} — plain strings, not ObjectIds.

gg_openviking_inject_branch_context() {
  local account_id="$1" branch_id="$2" content="$3"
  gg_require "$account_id" "Usage: openviking inject-branch-context <accountId> <branchId> <content>"
  gg_require "$branch_id" "Usage: openviking inject-branch-context <accountId> <branchId> <content>"
  gg_require "$content" "Usage: openviking inject-branch-context <accountId> <branchId> <content>"
  local base token body
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  body="$(jq -n --arg accountId "$account_id" --arg branchId "$branch_id" --arg content "$content" \
    '{accountId: $accountId, branchId: $branchId, content: $content}')" || exit $?
  gg_http_or_die "openviking inject-branch-context" POST "${base}/v1/admin/openviking/inject-branch-context" --token "$token" --json "$body"
}

gg_openviking_upload_skill() {
  local account_id="$1" branch_id="$2" content="$3"
  gg_require "$account_id" "Usage: openviking upload-skill <accountId> <branchId> <content>"
  gg_require "$branch_id" "Usage: openviking upload-skill <accountId> <branchId> <content>"
  gg_require "$content" "Usage: openviking upload-skill <accountId> <branchId> <content>"
  local base token body
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  body="$(jq -n --arg accountId "$account_id" --arg branchId "$branch_id" --arg content "$content" \
    '{accountId: $accountId, branchId: $branchId, content: $content}')" || exit $?
  gg_http_or_die "openviking upload-skill" POST "${base}/v1/admin/openviking/upload-skill" --token "$token" --json "$body"
}

# --- Order (admin) ---

gg_order_admin_list() {
  local page="${1:-}" limit="${2:-}"
  local base token
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  local -a query=()
  [ -n "$page" ] && query+=(--query "page=${page}")
  [ -n "$limit" ] && query+=(--query "limit=${limit}")
  gg_http_or_die "order list" GET "${base}/v1/admin/order" --token "$token" "${query[@]+"${query[@]}"}"
}

gg_order_admin_get() {
  local id="$1" base token
  gg_require "$id" "Usage: order get <orderId>"
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  gg_http_or_die "order get" GET "${base}/v1/admin/order/${id}" --token "$token"
}

# --- Plan ---

gg_plan_get_by_slug() {
  local slug="$1" base token
  gg_require "$slug" "Usage: plan slug <slug>"
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  gg_http_or_die "plan by slug" GET "${base}/v1/admin/plan/slug/${slug}" --token "$token"
}

# --- QrCode (admin, extra) ---
# Base is /v1/admin/qr-code (confirmed — mounted at '/qr-code' in admin/index.ts).

gg_qrcode_available_partners() {
  local base token
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  gg_http_or_die "qrcode available-partners" GET "${base}/v1/admin/qr-code/available-partners" --token "$token"
}

gg_qrcode_available_tables() {
  local branch_id="$1" account_id="$2"
  gg_require "$branch_id" "Usage: qrcode available-tables <branchId> <accountId>"
  gg_require "$account_id" "Usage: qrcode available-tables <branchId> <accountId>"
  local base token
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  gg_http_or_die "qrcode available-tables" GET "${base}/v1/admin/qr-code/available-tables" --token "$token" \
    --query "branchId=${branch_id}" --query "accountId=${account_id}"
}

gg_qrcode_details() {
  local code="$1" base token
  gg_require "$code" "Usage: qrcode details <code>"
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  gg_http_or_die "qrcode details" GET "${base}/v1/admin/qr-code/details" --token "$token" --query "code=${code}"
}

# --- WABA resolve ---
# Auth is authJwtOrApiKey — a Bearer JWT OR an `X-Api-Key` header, NOT "no auth" (confirmed
# against src/modules/apiKey/apiKey.middleware.ts). Used here with the WABA middleware service
# API key over X-Api-Key, per the task spec's intent (a separate credential from the admin
# bearer token) — requires GG_WABA_MIDDLEWARE_API_KEY from credentials.env.

gg_waba_resolve_account() {
  local waba_id="$1" caller_key_id="$2"
  gg_require "$waba_id" "Usage: waba resolve-account <wabaId> <callerKeyId>"
  gg_require "$caller_key_id" "Usage: waba resolve-account <wabaId> <callerKeyId>"
  gg_load_credentials
  gg_require "${GG_WABA_MIDDLEWARE_API_KEY:-}" "GG_WABA_MIDDLEWARE_API_KEY not set — see scripts/config/credentials.example.env"
  local base body
  base="$(gg_session_get base)" || exit $?
  body="$(jq -n --arg wabaId "$waba_id" --arg callerKeyId "$caller_key_id" '{wabaId: $wabaId, callerKeyId: $callerKeyId}')" || exit $?
  gg_http_or_die "waba resolve-account" POST "${base}/v1/admin/waba/resolve-account" \
    --header "X-Api-Key: ${GG_WABA_MIDDLEWARE_API_KEY}" --json "$body"
}

# gg_waba_resolve_platform_inbound <phoneNumberId> [waId]
gg_waba_resolve_platform_inbound() {
  local phone_number_id="$1" wa_id="${2:-}"
  gg_require "$phone_number_id" "Usage: waba resolve-platform-inbound <phoneNumberId> [waId]"
  gg_load_credentials
  gg_require "${GG_WABA_MIDDLEWARE_API_KEY:-}" "GG_WABA_MIDDLEWARE_API_KEY not set — see scripts/config/credentials.example.env"
  local base body
  base="$(gg_session_get base)" || exit $?
  body="$(jq -n --arg phoneNumberId "$phone_number_id" --arg waId "$wa_id" \
    '{phoneNumberId: $phoneNumberId} + (if $waId != "" then {waId: $waId} else {} end)')" || exit $?
  gg_http_or_die "waba resolve-platform-inbound" POST "${base}/v1/admin/waba/resolve-platform-inbound" \
    --header "X-Api-Key: ${GG_WABA_MIDDLEWARE_API_KEY}" --json "$body"
}

# --- WhatsAppTemplate ---
# Base is /v1/admin/whatsapp/templates (confirmed — mounted at '/whatsapp/templates' in
# admin/index.ts), NOT /v1/admin/whatsapp-template.

gg_whatsapp_template_reprovision() {
  local partner_id="$1" base token body
  gg_require "$partner_id" "Usage: whatsapp-template re-provision <partnerId>"
  base="$(gg_session_get base)" || exit $?
  token="$(gg_admin_token)" || exit $?
  body="$(jq -n --arg partnerId "$partner_id" '{partnerId: $partnerId}')" || exit $?
  gg_http_or_die "whatsapp-template re-provision" POST "${base}/v1/admin/whatsapp/templates/re-provision" --token "$token" --json "$body"
}
