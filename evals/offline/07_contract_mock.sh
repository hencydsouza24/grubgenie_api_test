#!/usr/bin/env bash
# Runs the real lib/http.sh (and, if pwsh is present, lib/Http.ps1) against a local stub server —
# this is what makes the error-handling contract testable with no live API. Exit: 2 if python3
# is missing (required, not optional — but every environment running this skill already needs it
# per SKILL.md); otherwise 0 pass / 1 fail.
set -uo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STUB="$SKILL_DIR/evals/fixtures/stub_server.py"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not installed"
  exit 2
fi

PORT_FILE="$(mktemp)"
python3 "$STUB" 0 > "$PORT_FILE" 2>/dev/null &
STUB_PID=$!
trap 'kill "$STUB_PID" 2>/dev/null; rm -f "$PORT_FILE"' EXIT

for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -s "$PORT_FILE" ] && break
  sleep 0.2
done
PORT="$(cat "$PORT_FILE")"
if [ -z "$PORT" ]; then
  echo "stub server never reported a port"
  exit 1
fi
BASE="http://127.0.0.1:$PORT"

fail=0
assert_eq() { # assert_eq <label> <actual> <expected>
  if [ "$2" != "$3" ]; then
    echo "FAIL: $1 — got '$2', expected '$3'"
    fail=1
  fi
}
# Pull the value out by a distinct line-prefix rather than a line number — robust against any
# extra noise (e.g. a logging bug) interleaving with the tagged output lines.
field() { grep "^$1:" <<< "$2" | head -1 | cut -d: -f2-; }

# --- bash assertions ---
# Each case uses if/then/else, not `cmd || rc=$?` — the latter only assigns rc on FAILURE, so a
# later successful call silently keeps a previous call's rc. That's exactly the footgun this
# harness exists to catch, so the harness itself must not fall into it.
bash_result="$(BASE="$BASE" bash -c '
  source "'"$SKILL_DIR"'/scripts/lib/bootstrap.sh"

  if body=$(gg_get /status/200); then rc=0; else rc=$?; fi
  echo "T1:$rc:$(gg_http_status):$body"

  if body=$(gg_get /status/401); then rc=0; else rc=$?; fi
  echo "T2:$rc:$(gg_http_status):$body"

  if body=$(gg_get /status/500); then rc=0; else rc=$?; fi
  echo "T3:$rc:$(gg_http_status)"

  if body=$(gg_get /status/401 --expect 401); then rc=0; else rc=$?; fi
  echo "T4:$rc:$(gg_http_status)"
')"

assert_eq "bash: 200 -> exit 0"              "$(field T1 "$bash_result" | cut -d: -f1)" "0"
assert_eq "bash: 200 -> status 200"          "$(field T1 "$bash_result" | cut -d: -f2)" "200"
assert_eq "bash: 401 -> exit 4"              "$(field T2 "$bash_result" | cut -d: -f1)" "4"
assert_eq "bash: 401 -> body still returned" "$(field T2 "$bash_result" | cut -d: -f3-)" '{"message": "status 401"}'
assert_eq "bash: 500 -> exit 5"              "$(field T3 "$bash_result" | cut -d: -f1)" "5"
assert_eq "bash: 401 --expect 401 -> exit 0" "$(field T4 "$bash_result" | cut -d: -f1)" "0"

# GG_CONNECT_TIMEOUT is `readonly` once bootstrap.sh runs — it must be set as an env var BEFORE
# sourcing, not assigned after (that's the correct override mechanism, and this is a regression
# check for that: the wrong way should never look like it silently worked).
BASE="http://127.0.0.1:1" GG_CONNECT_TIMEOUT=1 bash -c '
  source "'"$SKILL_DIR"'/scripts/lib/bootstrap.sh"
  gg_get /nowhere >/dev/null 2>&1
' >/dev/null 2>&1
assert_eq "bash: unreachable -> exit 7" "$?" "7"

BASE="$BASE" bash -c '
  source "'"$SKILL_DIR"'/scripts/lib/bootstrap.sh"
  body=$(gg_get /contract/missing)
  gg_json_field "$body" ".result.cartId" "cartId"
' >/dev/null 2>&1
assert_eq "bash: missing contract field -> exit 6" "$?" "6"

# --- PowerShell assertions + cross-language parity (skip cleanly if pwsh absent) ---
if command -v pwsh >/dev/null 2>&1; then
  # ${Script:Var} curly-brace form, not bare $Script:Var — PowerShell's scope-qualified
  # interpolation is ambiguous when a literal ':' immediately follows the variable name (as it
  # does in this ":"-delimited output format), and silently drops the whole expression instead
  # of erroring.
  ps_result="$(BASE="$BASE" pwsh -NoProfile -Command "
    . '$SKILL_DIR/scripts/powershell/lib/Bootstrap.ps1'

    \$b1 = Invoke-GgGet -Path '/status/200'
    Write-Output \"T1:\${Script:GgHttpExitCode}:\${Script:GgHttpStatus}:\$b1\"

    \$b2 = Invoke-GgGet -Path '/status/401'
    Write-Output \"T2:\${Script:GgHttpExitCode}:\${Script:GgHttpStatus}:\$b2\"

    \$b3 = Invoke-GgGet -Path '/status/500'
    Write-Output \"T3:\${Script:GgHttpExitCode}:\${Script:GgHttpStatus}\"

    \$b4 = Invoke-GgGet -Path '/status/401' -Expect '401'
    Write-Output \"T4:\${Script:GgHttpExitCode}:\${Script:GgHttpStatus}\"
  " 2>/dev/null)"

  assert_eq "ps: 200 -> exit 0"              "$(field T1 "$ps_result" | cut -d: -f1)" "0"
  assert_eq "ps: 200 -> status 200"          "$(field T1 "$ps_result" | cut -d: -f2)" "200"
  assert_eq "ps: 401 -> exit 4"              "$(field T2 "$ps_result" | cut -d: -f1)" "4"
  assert_eq "ps: 401 -> body still returned" "$(field T2 "$ps_result" | cut -d: -f3-)" '{"message": "status 401"}'
  assert_eq "ps: 500 -> exit 5"              "$(field T3 "$ps_result" | cut -d: -f1)" "5"
  assert_eq "ps: 401 --expect 401 -> exit 0" "$(field T4 "$ps_result" | cut -d: -f1)" "0"

  # Assertion 8 — the executable definition of "full parity": identical exit codes for every
  # case above, bash vs PowerShell.
  for t in T1 T2 T3 T4; do
    bash_rc="$(field "$t" "$bash_result" | cut -d: -f1)"
    ps_rc="$(field "$t" "$ps_result" | cut -d: -f1)"
    assert_eq "parity: $t exit code (bash vs ps)" "$ps_rc" "$bash_rc"
  done
else
  echo "note: pwsh not found — PowerShell + cross-language parity assertions skipped"
fi

exit $fail
