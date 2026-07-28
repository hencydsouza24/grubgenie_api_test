#!/usr/bin/env bash
# Structured narration — stderr only, never stdout. Sourced by bootstrap.sh.

[ "${BASH_SOURCE[0]}" = "$0" ] && { echo "lib/log.sh is a library — source it, don't execute it." >&2; exit 1; }

gg_info()  { printf '[info] %s\n'  "$*" >&2; }
gg_warn()  { printf '[warn] %s\n'  "$*" >&2; }
gg_error() { printf '[error] %s\n' "$*" >&2; }

gg_step() {
  local n="$1"; shift
  printf '\n=== Step %s: %s ===\n' "$n" "$*" >&2
}

gg_kv() { printf '  %-14s %s\n' "$1:" "$2" >&2; }

# gg_die <exit_code> <message...>
gg_die() {
  local code="$1"; shift
  gg_error "$*"
  exit "$code"
}

# gg_require <value> <message...> → dies with GG_EXIT_USAGE if value is empty.
#
# Prefer this over bash's own `${VAR:?message}`. That mechanism has a confirmed bash quirk:
# under an EXIT trap (which lib/http.sh always registers, to clean up its status-file), a `:?`
# failure's exit code gets silently reset to whatever the trap's last command returns (0 for
# `rm -f`), instead of bash's normal nonzero status — `$?` inside the trap reads back as 0 for a
# `:?` failure specifically, unlike an explicit `exit N` or an ordinary `set -e` failure, both of
# which correctly survive the trap. gg_require sidesteps the whole quirk by using gg_die's
# explicit `exit`, the one mechanism confirmed reliable in every case tested.
gg_require() {
  local value="$1"; shift
  [ -n "$value" ] || gg_die "$GG_EXIT_USAGE" "$*"
}
