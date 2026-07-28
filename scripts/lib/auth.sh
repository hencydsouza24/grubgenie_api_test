#!/usr/bin/env bash
# Idempotent session acquisition + session-file persistence. Sourced by bootstrap.sh.
#
# The session file is the composition primitive that works identically in bash and PowerShell:
# `eval "$(bash auth.sh)"` has no PS equivalent, `$env:` mutation has no bash-subprocess
# equivalent, a file on disk has both.

[ "${BASH_SOURCE[0]}" = "$0" ] && { echo "lib/auth.sh is a library — source it, don't execute it." >&2; exit 1; }
#
# IMPORTANT: every `var="$(some_function ...)"` line below is followed by `|| exit $?`. This is
# not defensive style — it's load-bearing. Bash's `set -e` does NOT reliably auto-abort when a
# command substitution's inner command is itself a function that calls `exit` two or more levels
# of `$(...)` nesting deep (confirmed on bash 3.2, the default /bin/bash on macOS — no
# `inherit_errexit` shopt exists there to fix it). Without the explicit `|| exit $?`, a failed
# auth step here silently falls through to the next step with an empty variable, producing a
# cascade of misleading "field missing" errors that mask the real (e.g. connection) failure. Any
# new function added to this file must follow the same pattern.

# gg_session_path [env_name] → path to the session file for that environment.
gg_session_path() {
  local name="${1:-$(gg_env_name)}"
  echo "${GG_SESSION_FILE:-${TMPDIR:-/tmp}/grubgenie-session-${name}.json}"
}

# gg_load_credentials → sources scripts/config/credentials.env if present. Silent no-op if
# absent; only gg_auth_admin and gg_pos_config_setup need it.
gg_load_credentials() {
  local cred_file="$GG_SKILL_DIR/config/credentials.env"
  # shellcheck disable=SC1090
  [ -f "$cred_file" ] && source "$cred_file"
  return 0
}

_gg_session_fresh() {
  local path="$1" now mtime age
  [ -f "$path" ] || return 1
  now=$(date +%s)
  if mtime=$(stat -f %m "$path" 2>/dev/null) || mtime=$(stat -c %Y "$path" 2>/dev/null); then
    age=$((now - mtime))
    [ "$age" -lt "$GG_SESSION_TTL" ]
  else
    return 1
  fi
}

gg_auth_partner() {
  local base="$1" body resp
  body="$(jq -n --arg email "$GG_PARTNER_EMAIL" --arg password "$GG_PARTNER_PASSWORD" \
    '{email: $email, password: $password}')" || exit $?
  resp="$(gg_http_or_die "partner signin" POST "${base}/v1/partner/auth/signin" --json "$body")" || exit $?
  gg_json_field "$resp" '.result.accessToken' "partner accessToken"
}

# gg_auth_admin — requires GG_ADMIN_EMAIL / GG_ADMIN_PASSWORD from credentials.env.
gg_auth_admin() {
  local base="$1" body resp
  gg_load_credentials
  gg_require "${GG_ADMIN_EMAIL:-}" "GG_ADMIN_EMAIL not set — see scripts/config/credentials.example.env"
  gg_require "${GG_ADMIN_PASSWORD:-}" "GG_ADMIN_PASSWORD not set — see scripts/config/credentials.example.env"
  body="$(jq -n --arg email "$GG_ADMIN_EMAIL" --arg password "$GG_ADMIN_PASSWORD" \
    '{email: $email, password: $password}')" || exit $?
  resp="$(gg_http_or_die "admin signin" POST "${base}/v1/admin/auth/signin" --json "$body")" || exit $?
  gg_json_field "$resp" '.result.accessToken' "admin accessToken"
}

# gg_jwt_field <token> <claim> → decode a JWT's payload (base64url, unverified — same trust
# level as everywhere else in this skill, which already holds the bearer token in plaintext) and
# print one claim.
gg_jwt_field() {
  local token="$1" claim="$2"
  python3 -c "
import base64, json, sys
p = sys.argv[1].split('.')[1]
p += '=' * (-len(p) % 4)
print(json.loads(base64.urlsafe_b64decode(p)).get(sys.argv[2], ''))
" "$token" "$claim"
}

# gg_auth_diner <base> <partner_token> → prints {"branchId","tableId","dinerToken","dinerId"}
#
# branchId is decoded from the PARTNER TOKEN's own claim, not a hardcoded constant. A partner
# account can have multiple branches (confirmed live: this test account has 9), and the JWT's
# branchId reflects whichever one is CURRENTLY SELECTED via /v1/partner/branch/switch-branch —
# the account's active branch can change over time. A fixed literal here goes stale the moment
# someone switches branches: /v1/partner/table (called with this same token) returns tables
# scoped to the active branch, so if the diner authenticates against a DIFFERENT branchId than
# the partner's active one, cart creation 404s ("Table not found") even though both branchIds are
# individually valid. Matching the diner's branch to the partner token's own branch is what keeps
# table lookups and diner auth pointed at the same place regardless of which branch is active.
gg_auth_diner() {
  local base="$1" partner_token="$2"
  local resp table_id diner_resp diner_token diner_id branch_id

  branch_id="$(gg_jwt_field "$partner_token" branchId)" || exit $?
  [ -n "$branch_id" ] || gg_die "$GG_EXIT_CONTRACT" "could not decode branchId from partner token"

  resp="$(gg_http_or_die "table fetch" GET "${base}/v1/partner/table" --token "$partner_token")" || exit $?
  table_id="$(gg_json_field "$resp" '.result[0]._id' "table id")" || exit $?

  diner_resp="$(gg_http_or_die "diner auth" GET "${base}/v1/genie/diner" \
    --query "customDomain=${GG_CUSTOM_DOMAIN}" \
    --query "branchId=${branch_id}" \
    --query "fingerprint=${GG_FINGERPRINT}")" || exit $?

  diner_token="$(gg_json_field "$diner_resp" '.result.accessToken' "diner accessToken")" || exit $?
  diner_id="$(gg_json_field "$diner_resp" '.result._id' "diner id")" || exit $?

  jq -n --arg branchId "$branch_id" --arg tableId "$table_id" --arg dinerToken "$diner_token" --arg dinerId "$diner_id" \
    '{branchId: $branchId, tableId: $tableId, dinerToken: $dinerToken, dinerId: $dinerId}'
}

# gg_auth_ensure [--force] → writes/refreshes the session file for the current environment and
# prints its path. Idempotent: reuses a fresh (< GG_SESSION_TTL seconds old) session unless
# --force or the file is stale/missing.
gg_auth_ensure() {
  local force=0
  [ "${1:-}" = "--force" ] && force=1

  local env base path
  env="$(gg_env_name)"
  base="$(gg_resolve_base)"
  path="$(gg_session_path "$env")"

  if [ "$force" -eq 0 ] && _gg_session_fresh "$path"; then
    echo "$path"
    return 0
  fi

  gg_step 1 "Authenticating ($env)"
  local partner_token diner_json branch_id table_id diner_token diner_id session

  partner_token="$(gg_auth_partner "$base")" || exit $?
  diner_json="$(gg_auth_diner "$base" "$partner_token")" || exit $?
  branch_id="$(gg_json_field "$diner_json" '.branchId' "branchId")" || exit $?
  table_id="$(gg_json_field "$diner_json" '.tableId' "tableId")" || exit $?
  diner_token="$(gg_json_field "$diner_json" '.dinerToken' "dinerToken")" || exit $?
  diner_id="$(gg_json_field "$diner_json" '.dinerId' "dinerId")" || exit $?

  session="$(jq -n \
    --arg base "$base" \
    --arg env "$env" \
    --arg branchId "$branch_id" \
    --arg partnerToken "$partner_token" \
    --arg tableId "$table_id" \
    --arg dinerToken "$diner_token" \
    --arg dinerId "$diner_id" \
    '{base: $base, env: $env, branchId: $branchId, partnerToken: $partnerToken,
      tableId: $tableId, dinerToken: $dinerToken, dinerId: $dinerId}')" || exit $?

  printf '%s' "$session" > "$path"
  chmod 600 "$path"

  gg_kv "Partner token" "${partner_token:0:20}..."
  gg_kv "Table" "$table_id"
  gg_kv "Diner" "$diner_id"

  echo "$path"
}

# gg_session_get <key> → reads one field from the current session, auth'ing first if needed.
gg_session_get() {
  local key="$1" path
  path="$(gg_auth_ensure)" || exit $?
  jq -r --arg k "$key" '.[$k]' "$path"
}
