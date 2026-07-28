#!/usr/bin/env bash
# GrubGenie skill eval harness. Usage: run_evals.sh [--offline|--live|--all]
# --offline (default): safe with no API running — syntax, lint, conventions, secret gate,
#                       parity, and the contract-mock suite against a local stub server.
# --live:               requires a real API at $BASE (see scripts/env.sh).
#
# Each check script in evals/offline|live/*.sh exits: 0 = pass, 2 = skip (optional tool/module
# missing), anything else = fail. A check named *.advisory.sh is reported but never fails the
# suite — it's a gate scheduled to go blocking in a later phase (see the refactor plan).

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVALS_DIR="$SKILL_DIR/evals"
MODE="${1:---offline}"

PASS=0
FAIL=0
SKIP=0

run_check() {
  local name="$1" path="$2" out rc advisory=0
  case "$path" in *.advisory.*) advisory=1 ;; esac

  out="$(bash "$path" 2>&1)"
  rc=$?

  if [ "$advisory" -eq 1 ] && [ "$rc" -ne 2 ]; then
    SKIP=$((SKIP + 1))
    if [ "$rc" -eq 0 ]; then
      echo "SKIP  $name (advisory — currently passing)"
    else
      echo "SKIP  $name (advisory — not yet gating; currently failing, see refactor plan)"
      echo "$out" | sed 's/^/      /'
    fi
    return
  fi

  case "$rc" in
    0)
      PASS=$((PASS + 1))
      echo "PASS  $name"
      ;;
    2)
      SKIP=$((SKIP + 1))
      echo "SKIP  $name — $(echo "$out" | head -1)"
      ;;
    *)
      FAIL=$((FAIL + 1))
      echo "FAIL  $name"
      echo "$out" | sed 's/^/      /'
      ;;
  esac
}

run_dir() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  local check
  for check in "$dir"/*.sh; do
    [ -e "$check" ] || continue
    run_check "$(basename "$check" .sh)" "$check"
  done
}

case "$MODE" in
  --offline) run_dir "$EVALS_DIR/offline" ;;
  --live)    run_dir "$EVALS_DIR/live" ;;
  --all)     run_dir "$EVALS_DIR/offline"; run_dir "$EVALS_DIR/live" ;;
  *)
    echo "Usage: run_evals.sh [--offline|--live|--all]" >&2
    exit 2
    ;;
esac

echo ""
echo "PASS $PASS / FAIL $FAIL / SKIP $SKIP"
[ "$FAIL" -eq 0 ]
