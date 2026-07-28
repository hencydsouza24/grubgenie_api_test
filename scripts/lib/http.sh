#!/usr/bin/env bash
# HTTP transport. Owns status handling. Knows nothing about domain semantics — see api.sh.
# Sourced by bootstrap.sh.

[ "${BASH_SOURCE[0]}" = "$0" ] && { echo "lib/http.sh is a library — source it, don't execute it." >&2; exit 1; }

# GG_HTTP_STATUS is set by every gg_http call, but the common calling pattern
# `body="$(gg_http ...)"` runs gg_http in a subshell (command substitution) — a plain variable
# assigned there is invisible to the caller once the subshell exits. $$ stays the top-level
# shell's PID across subshells (unlike $BASHPID), so a per-PID status file survives the
# boundary. gg_http_status reads it back; GG_HTTP_STATUS is still set for direct (non-subshelled)
# callers, but code that calls gg_http via command substitution MUST use gg_http_status instead.
GG_HTTP_STATUS=""
GG_HTTP_STATUS_FILE="${TMPDIR:-/tmp}/.gg-http-status.$$"
# `rc=$?` first, then re-`exit "$rc"` at the end — NOT just `rm -f "$GG_HTTP_STATUS_FILE"` alone.
# A bare cleanup command as the trap body lets its own (successful) exit status silently become
# the script's final exit code for certain failure paths (confirmed for bash's `${VAR:?msg}`,
# where $? reads back as 0 inside an EXIT trap regardless of the real failure) — capturing $?
# before running anything else in the trap, then explicitly re-exiting with it, is what actually
# preserves the script's true exit code in every case.
trap 'rc=$?; rm -f "$GG_HTTP_STATUS_FILE"; exit "$rc"' EXIT

gg_http_status() {
  cat "$GG_HTTP_STATUS_FILE" 2>/dev/null || echo "000"
}

# _gg_expect_match <status> <spec>
# spec: "2xx"-style class match | "any" | comma list of exact codes, e.g. "400,409"
_gg_expect_match() {
  local status="$1" spec="$2" code
  [ "$spec" = "any" ] && return 0
  local IFS=','
  local -a parts
  read -ra parts <<< "$spec"
  for code in "${parts[@]}"; do
    case "$code" in
      [0-9]xx)
        [ "${status:0:1}" = "${code:0:1}" ] && return 0
        ;;
      *)
        [ "$status" = "$code" ] && return 0
        ;;
    esac
  done
  return 1
}

# gg_http <METHOD> <PATH_OR_URL> [--token T] [--json BODY] [--query K=V]... [--expect SPEC]
#
# stdout: raw response body bytes, nothing else.
# stderr: one narration line.
# $GG_HTTP_STATUS: the numeric status, or "000" if unreachable.
#
# Returns 0 if status matches --expect (default "2xx"). Otherwise returns WITHOUT dying:
#   4  unexpected 4xx     5  unexpected 5xx     7  unreachable (DNS/refused/timeout)
# Callers decide whether to abort — see gg_http_or_die for the common "must succeed" case.
gg_http() {
  local method="$1" target="$2"; shift 2
  local token="" json_body="" expect="2xx"
  local -a query_parts=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --token)  token="$2"; shift 2 ;;
      --json)   json_body="$2"; shift 2 ;;
      --query)  query_parts+=("$2"); shift 2 ;;
      --expect) expect="$2"; shift 2 ;;
      *) gg_die "$GG_EXIT_USAGE" "gg_http: unknown option $1" ;;
    esac
  done

  local url
  if [[ "$target" == http://* || "$target" == https://* ]]; then
    url="$target"
  else
    url="$(gg_resolve_base)${target}"
  fi

  if [ "${#query_parts[@]}" -gt 0 ]; then
    local qs="" part
    for part in "${query_parts[@]}"; do
      qs="${qs:+$qs&}$part"
    done
    case "$url" in
      *\?*) url="${url}&${qs}" ;;
      *)    url="${url}?${qs}" ;;
    esac
  fi

  local -a curl_args=(-sS -L --connect-timeout "$GG_CONNECT_TIMEOUT" --max-time "$GG_MAX_TIME" -X "$method")
  [ -n "$token" ] && curl_args+=(-H "Authorization: Bearer $token")
  if [ -n "$json_body" ]; then
    curl_args+=(-H "Content-Type: application/json" -d "$json_body")
  fi

  local body_file status
  body_file="$(mktemp "${TMPDIR:-/tmp}/gg-http.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -f '$body_file'" RETURN

  status="$(curl "${curl_args[@]}" -o "$body_file" -w '%{http_code}' "$url" 2>/dev/null)" || status="000"
  GG_HTTP_STATUS="$status"
  printf '%s' "$status" > "$GG_HTTP_STATUS_FILE"

  gg_info "$method $url -> $status"
  cat "$body_file"

  if [ "$status" = "000" ]; then
    return "$GG_EXIT_TRANSPORT"
  fi
  if _gg_expect_match "$status" "$expect"; then
    return "$GG_EXIT_OK"
  fi
  case "${status:0:1}" in
    4) return "$GG_EXIT_CLIENT" ;;
    *) return "$GG_EXIT_SERVER" ;;
  esac
}

gg_get()    { gg_http GET    "$1" "${@:2}"; }
gg_post()   { gg_http POST   "$1" "${@:2}"; }
gg_put()    { gg_http PUT    "$1" "${@:2}"; }
gg_patch()  { gg_http PATCH  "$1" "${@:2}"; }
gg_delete() { gg_http DELETE "$1" "${@:2}"; }

# gg_http_or_die <label> <METHOD> <PATH_OR_URL> [gg_http opts...]
# Same as gg_http, but on a non-success return it prints <label> + status + a body excerpt and
# exits with the SAME mapped code gg_http returned (never the raw HTTP status — exit codes above
# 255 wrap silently, which is exactly the kind of bug this function exists to prevent).
gg_http_or_die() {
  local label="$1"; shift
  local body rc status
  body="$(gg_http "$@")" && rc=0 || rc=$?
  status="$(gg_http_status)"
  if [ "$rc" -ne 0 ]; then
    gg_error "$label failed (HTTP ${status})"
    gg_error "response: $(printf '%s' "$body" | head -c 300)"
    exit "$rc"
  fi
  printf '%s' "$body"
}
