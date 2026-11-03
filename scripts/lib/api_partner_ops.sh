#!/usr/bin/env bash
# Partner Ops domain verbs — bundles three read-heavy admin groups plus the four new Table chair
# actions that don't yet have a home in api.sh's existing gg_tables_list/gg_table_set_status:
#   - AllOutlets  (/v1/partner/all-outlets)  — cross-branch rollup reads + one write (mark-read)
#   - Queue       (/v1/partner/queue)        — walk-in queue CRUD + 5 state-transition actions
#   - Role        (/v1/partner/roles)        — custom partner roles. NOTE: the route is mounted
#     at `/v1/partner/roles` (plural) in src/routes/v1/partner/index.ts, NOT `/v1/partner/role`.
#   - Table       (/v1/partner/table)        — split / merge / borrow-chair / return-chair, on
#     top of the table.route.ts base that gg_tables_list/gg_table_set_status already use.
#
# Expressed over http.sh + json.sh, exactly like api.sh. Not yet sourced by bootstrap.sh (wired
# centrally later to avoid collisions with sibling lib files being added in parallel) — scripts
# that need these functions source this file directly, after bootstrap.sh.
#
# IMPORTANT: every `var="$(some_function ...)"` line below is followed by `|| exit $?` — see
# api.sh's header comment for why this is load-bearing on bash 3.2 (macOS's default /bin/bash)
# and not just defensive style. Any new function added to this file must follow the same pattern.

[ "${BASH_SOURCE[0]}" = "$0" ] && { echo "lib/api_partner_ops.sh is a library — source it, don't execute it." >&2; exit 1; }

# ============================= AllOutlets =============================

gg_all_outlets_list() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "all-outlets list" GET "${base}/v1/partner/all-outlets/outlets" --token "$partner_token"
}

# gg_all_outlets_inquiries [key=value ...] — optional: branchId, page, limit, status, inquiryType, q.
gg_all_outlets_inquiries() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  local -a q=()
  local kv
  for kv in "$@"; do q+=(--query "$kv"); done
  gg_http_or_die "all-outlets inquiries" GET "${base}/v1/partner/all-outlets/inquiries" --token "$partner_token" "${q[@]+"${q[@]}"}"
}

# gg_all_outlets_reservations [key=value ...] — `after` and `before` (ISO dates) are REQUIRED by
# allOutlets.validation.ts; pass them as two of the key=value pairs, e.g.
#   gg_all_outlets_reservations "after=2026-01-01" "before=2026-01-31"
gg_all_outlets_reservations() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  local -a q=()
  local kv
  for kv in "$@"; do q+=(--query "$kv"); done
  gg_http_or_die "all-outlets reservations" GET "${base}/v1/partner/all-outlets/reservations" --token "$partner_token" "${q[@]+"${q[@]}"}"
}

# gg_all_outlets_queue [key=value ...] — optional: branchId only.
gg_all_outlets_queue() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  local -a q=()
  local kv
  for kv in "$@"; do q+=(--query "$kv"); done
  gg_http_or_die "all-outlets queue" GET "${base}/v1/partner/all-outlets/queue" --token "$partner_token" "${q[@]+"${q[@]}"}"
}

gg_all_outlets_notifications() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "all-outlets notifications" GET "${base}/v1/partner/all-outlets/notifications" --token "$partner_token"
}

# gg_all_outlets_notifications_read <branch_id> <notification_id> [notification_id...] → marks
# that one branch's notifications read (single group in the `items` array — this skill's scripts
# always drive one branch at a time, so a multi-branch batch would be unused flexibility). Prints
# the response message.
gg_all_outlets_notifications_read() {
  local branch_id="$1"; shift
  local base partner_token body resp ids_json
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  ids_json="$(printf '%s\n' "$@" | jq -R -s -c 'split("\n") | map(select(length > 0))')" || exit $?
  body="$(jq -n --arg branchId "$branch_id" --argjson ids "$ids_json" \
    '{items: [{branchId: $branchId, notificationIds: $ids}]}')" || exit $?
  resp="$(gg_http_or_die "all-outlets notifications read" PUT "${base}/v1/partner/all-outlets/notifications/read" \
    --token "$partner_token" --json "$body")" || exit $?
  gg_json_message "$resp"
}

# ============================= Queue =============================

# gg_queue_create <guest_name> <guest_phone> <party_size> [quoted_wait_min] [preference_note] →
# prints the created entry's queueId.
gg_queue_create() {
  local guest_name="$1" guest_phone="$2" party_size="$3" quoted_wait_min="${4:-}" preference_note="${5:-}"
  local base partner_token body resp
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  body="$(jq -n \
    --arg guestName "$guest_name" --arg guestPhone "$guest_phone" --argjson partySize "$party_size" \
    --arg quotedWaitMin "$quoted_wait_min" --arg preferenceNote "$preference_note" \
    '{guestName: $guestName, guestPhone: $guestPhone, partySize: $partySize}
     + (if $quotedWaitMin != "" then {quotedWaitMin: ($quotedWaitMin | tonumber)} else {} end)
     + (if $preferenceNote != "" then {preferenceNote: $preferenceNote} else {} end)')" || exit $?
  resp="$(gg_http_or_die "queue create" POST "${base}/v1/partner/queue" --token "$partner_token" --json "$body")" || exit $?
  gg_json_field "$resp" '.result._id' "queueId"
}

# gg_queue_list [key=value ...] — optional: include=all, status, joinedAfter, joinedBefore, q, limit.
gg_queue_list() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  local -a q=()
  local kv
  for kv in "$@"; do q+=(--query "$kv"); done
  gg_http_or_die "queue list" GET "${base}/v1/partner/queue" --token "$partner_token" "${q[@]+"${q[@]}"}"
}

gg_queue_get() {
  local queue_id="$1"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "queue get" GET "${base}/v1/partner/queue/${queue_id}" --token "$partner_token"
}

# gg_queue_update <queue_id> [guest_name] [guest_phone] [party_size] [quoted_wait_min]
# [preference_note] — pass "-" (the skip sentinel) for any field you don't want to change; at
# least one real field must be supplied (queue.validation.ts requires body.min(1)).
gg_queue_update() {
  local queue_id="$1"
  local guest_name="${2:--}" guest_phone="${3:--}" party_size="${4:--}" quoted_wait_min="${5:--}" preference_note="${6:--}"
  local base partner_token body resp
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  body="$(jq -n \
    --arg guestName "$guest_name" --arg guestPhone "$guest_phone" --arg partySize "$party_size" \
    --arg quotedWaitMin "$quoted_wait_min" --arg preferenceNote "$preference_note" \
    '{guestName: $guestName, guestPhone: $guestPhone, partySize: $partySize,
       quotedWaitMin: $quotedWaitMin, preferenceNote: $preferenceNote}
     | with_entries(select(.value != "-"))
     | if has("partySize") then .partySize |= tonumber else . end
     | if has("quotedWaitMin") then .quotedWaitMin |= tonumber else . end')" || exit $?
  resp="$(gg_http_or_die "queue update" PUT "${base}/v1/partner/queue/${queue_id}" --token "$partner_token" --json "$body")" || exit $?
  printf '%s' "$resp"
}

# gg_queue_delete <queue_id> → prints the response message.
gg_queue_delete() {
  local queue_id="$1"
  local base partner_token resp
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  resp="$(gg_http_or_die "queue delete" DELETE "${base}/v1/partner/queue/${queue_id}" --token "$partner_token")" || exit $?
  gg_json_message "$resp"
}

# gg_queue_notify <queue_id> — `notify` takes an empty body (queueValidation.transitionEmpty).
gg_queue_notify() {
  local queue_id="$1"
  local base partner_token resp
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  resp="$(gg_http_or_die "queue notify" POST "${base}/v1/partner/queue/${queue_id}/notify" --token "$partner_token" --json '{}')" || exit $?
  gg_json_message "$resp"
}

# gg_queue_table_ready <queue_id> [table_id] — body: {tableId?} (queueValidation.transitionSeat).
gg_queue_table_ready() {
  local queue_id="$1" table_id="${2:-}"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  body="$(jq -n --arg tableId "$table_id" 'if $tableId != "" then {tableId: $tableId} else {} end')" || exit $?
  gg_http_or_die "queue table-ready" POST "${base}/v1/partner/queue/${queue_id}/table-ready" \
    --token "$partner_token" --json "$body"
}

# gg_queue_seat <queue_id> [table_id] — same body shape as table-ready (both use transitionSeat).
gg_queue_seat() {
  local queue_id="$1" table_id="${2:-}"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  body="$(jq -n --arg tableId "$table_id" 'if $tableId != "" then {tableId: $tableId} else {} end')" || exit $?
  gg_http_or_die "queue seat" POST "${base}/v1/partner/queue/${queue_id}/seat" \
    --token "$partner_token" --json "$body"
}

# gg_queue_abandon <queue_id> [reason] — reason must be "staff" or "converted" if given
# (queueValidation.transitionAbandon); omit to leave unset.
gg_queue_abandon() {
  local queue_id="$1" reason="${2:-}"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  body="$(jq -n --arg reason "$reason" 'if $reason != "" then {reason: $reason} else {} end')" || exit $?
  gg_http_or_die "queue abandon" POST "${base}/v1/partner/queue/${queue_id}/abandon" \
    --token "$partner_token" --json "$body"
}

# gg_queue_reopen <queue_id> — empty body (queueValidation.transitionEmpty). Prints the message.
gg_queue_reopen() {
  local queue_id="$1"
  local base partner_token resp
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  resp="$(gg_http_or_die "queue reopen" POST "${base}/v1/partner/queue/${queue_id}/reopen" --token "$partner_token" --json '{}')" || exit $?
  gg_json_message "$resp"
}

# ============================= Role =============================
# NOTE: mounted at /v1/partner/roles (plural) — see file header.

# gg_role_permission_catalog [role_key] — roleKey is optional.
gg_role_permission_catalog() {
  local role_key="${1:-}"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  if [ -n "$role_key" ]; then
    gg_http_or_die "role permission catalog" GET "${base}/v1/partner/roles/permission-catalog" \
      --token "$partner_token" --query "roleKey=${role_key}"
  else
    gg_http_or_die "role permission catalog" GET "${base}/v1/partner/roles/permission-catalog" --token "$partner_token"
  fi
}

gg_role_list() {
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "role list" GET "${base}/v1/partner/roles" --token "$partner_token"
}

# gg_role_create <name> <permission> [permission...] — permission values must be real leaves from
# the permission vocabulary (src/config/roles.ts), e.g. `readBranch`, `getQueue`,
# `createQueueEntry` — not made-up strings; the server 400s on anything outside that vocabulary.
gg_role_create() {
  local name="$1"; shift
  local base partner_token body resp perms_json
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  perms_json="$(printf '%s\n' "$@" | jq -R -s -c 'split("\n") | map(select(length > 0))')" || exit $?
  body="$(jq -n --arg name "$name" --argjson permissions "$perms_json" '{name: $name, permissions: $permissions}')" || exit $?
  resp="$(gg_http_or_die "role create" POST "${base}/v1/partner/roles" --token "$partner_token" --json "$body")" || exit $?
  printf '%s' "$resp"
}

# gg_role_update <role_id> <name_or_dash> [permission...] — pass "-" for name_or_dash to leave the
# name unchanged; pass zero or more permission leaves to replace the permission set. At least one
# of {name, permissions} must end up in the body (role.validation.ts: `.or('name', 'permissions')`).
gg_role_update() {
  local role_id="$1" name="$2"; shift 2
  local base partner_token body resp perms_json
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  perms_json="$(printf '%s\n' "$@" | jq -R -s -c 'split("\n") | map(select(length > 0))')" || exit $?
  body="$(jq -n --arg name "$name" --argjson permissions "$perms_json" \
    '(if $name != "-" then {name: $name} else {} end)
     + (if ($permissions | length) > 0 then {permissions: $permissions} else {} end)')" || exit $?
  resp="$(gg_http_or_die "role update" PUT "${base}/v1/partner/roles/${role_id}" --token "$partner_token" --json "$body")" || exit $?
  printf '%s' "$resp"
}

# gg_role_delete <role_id> → prints the response message.
gg_role_delete() {
  local role_id="$1"
  local base partner_token resp
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  resp="$(gg_http_or_die "role delete" DELETE "${base}/v1/partner/roles/${role_id}" --token "$partner_token")" || exit $?
  gg_json_message "$resp"
}

# ============================= Table actions (new) =============================
# Additional to gg_tables_list/gg_table_set_status already in api.sh. Confirmed directly against
# src/routes/v1/partner/table.route.ts + table.validation.ts + table.controller.ts — all four
# routes live under the SAME /v1/partner/table base as the existing table functions.

# gg_table_split <table_id> <segment> <segment> [segment] [segment] — 2 to 4 seat-count integers
# that the table's current seats get divided into (table.validation.ts: segments min 2, max 4).
gg_table_split() {
  local table_id="$1"; shift
  local base partner_token body segments_json
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  segments_json="$(printf '%s\n' "$@" | jq -R -s -c 'split("\n") | map(select(length > 0) | tonumber)')" || exit $?
  body="$(jq -n --argjson segments "$segments_json" '{segments: $segments}')" || exit $?
  gg_http_or_die "table split" POST "${base}/v1/partner/table/${table_id}/split" --token "$partner_token" --json "$body"
}

# gg_table_merge <table_id> — merges this table's split segments back together. No body.
gg_table_merge() {
  local table_id="$1"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "table merge" POST "${base}/v1/partner/table/${table_id}/merge" --token "$partner_token" --json '{}'
}

# gg_table_borrow_chair <table_id> <from_table_id> [count] — borrows `count` (default 1, per
# table.validation.ts) chairs from from_table_id onto table_id. Response is the updated table doc;
# its `borrowedChairs[]` entries each carry their own `_id`, which is the `borrowId` that
# gg_table_return_chair needs — read it out of this call's output (e.g. `.result.borrowedChairs`)
# rather than this script auto-chaining, matching the skill's existing style of explicit-id args.
gg_table_borrow_chair() {
  local table_id="$1" from_table_id="$2" count="${3:-}"
  local base partner_token body
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  body="$(jq -n --arg fromTableId "$from_table_id" --arg count "$count" \
    '{fromTableId: $fromTableId} + (if $count != "" then {count: ($count | tonumber)} else {} end)')" || exit $?
  gg_http_or_die "table borrow chair" POST "${base}/v1/partner/table/${table_id}/borrow-chair" \
    --token "$partner_token" --json "$body"
}

# gg_table_return_chair <table_id> <borrow_id> — DELETE, not POST: confirmed against
# table.route.ts (`router.delete('/:tableId/borrow-chair/:borrowId', ...)`). No body; both the
# table and the specific borrow record (its `_id` from borrow-chair's response) are path params.
gg_table_return_chair() {
  local table_id="$1" borrow_id="$2"
  local base partner_token
  base="$(gg_session_get base)" || exit $?
  partner_token="$(gg_session_get partnerToken)" || exit $?
  gg_http_or_die "table return chair" DELETE "${base}/v1/partner/table/${table_id}/borrow-chair/${borrow_id}" --token "$partner_token"
}
