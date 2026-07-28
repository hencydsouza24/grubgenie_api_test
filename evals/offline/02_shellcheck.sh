#!/usr/bin/env bash
# shellcheck -S warning over every bash script. Exit: 2 (skip) if shellcheck isn't installed —
# it's an optional linter, its absence must never fail the suite.
set -uo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck not installed"
  exit 2
fi

fail=0
while IFS= read -r -d '' f; do
  shellcheck -S warning "$f" || fail=1
done < <(find "$SKILL_DIR/scripts" -name '*.sh' -print0)

exit $fail
