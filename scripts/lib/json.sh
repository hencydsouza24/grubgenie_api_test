#!/usr/bin/env bash
# JSON field extraction with validation, and simple body construction. Sourced by bootstrap.sh.

[ "${BASH_SOURCE[0]}" = "$0" ] && { echo "lib/json.sh is a library — source it, don't execute it." >&2; exit 1; }

# gg_json_field <json> <jq_path> <label> → prints the field; dies with GG_EXIT_CONTRACT if the
# field is null, missing, or empty. Treats "the response doesn't have what we needed" as one
# failure mode, distinct from a transport or HTTP-status failure.
gg_json_field() {
  local json="$1" path="$2" label="$3" value
  value="$(printf '%s' "$json" | jq -r "$path" 2>/dev/null)" || value=""
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    gg_error "expected field missing: $label ($path)"
    gg_error "response was: $(printf '%s' "$json" | head -c 400)"
    exit "$GG_EXIT_CONTRACT"
  fi
  printf '%s\n' "$value"
}

# gg_json_opt <json> <jq_path> [default] → prints the field, or default (or empty) if absent/null.
gg_json_opt() {
  local json="$1" path="$2" default="${3:-}" value
  value="$(printf '%s' "$json" | jq -r "$path" 2>/dev/null)" || value=""
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    printf '%s\n' "$default"
  else
    printf '%s\n' "$value"
  fi
}

# gg_json_message <json> → prints .message, falling back to the whole doc as compact JSON.
gg_json_message() {
  local json="$1"
  printf '%s' "$json" | jq -r '.message // tojson' 2>/dev/null || printf '%s\n' "$json"
}

# gg_json_obj k v [k v ...] → a JSON object of string fields, built with `jq -n --arg` (safe
# against quotes/backslashes/unicode — replaces shell string-interpolated JSON bodies). For
# bodies needing numbers/booleans, call `jq -n --arg --argjson ...` directly in api.sh instead.
gg_json_obj() {
  local -a jq_args=() pairs=()
  local i=1 key val
  while [ $# -gt 0 ]; do
    key="$1"; val="$2"; shift 2
    jq_args+=(--arg "k${i}" "$key" --arg "v${i}" "$val")
    pairs+=("(\$k${i}): \$v${i}")
    i=$((i + 1))
  done
  local filter
  filter="{$(IFS=,; echo "${pairs[*]}")}"
  jq -n "${jq_args[@]}" "$filter"
}
