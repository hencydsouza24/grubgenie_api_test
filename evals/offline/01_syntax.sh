#!/usr/bin/env bash
# Syntax-check every bash script (required) and every PowerShell script (best-effort, if pwsh
# is available). Exit: 0 pass, nonzero fail. Never skips — bash -n has no external dependency.
set -uo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0

while IFS= read -r -d '' f; do
  bash -n "$f" 2>&1 | sed "s|^|$f: |"
  # shellcheck disable=SC2181
  if ! bash -n "$f" >/dev/null 2>&1; then
    echo "syntax error: $f"
    fail=1
  fi
done < <(find "$SKILL_DIR/scripts" -name '*.sh' -print0)

if command -v pwsh >/dev/null 2>&1; then
  while IFS= read -r -d '' f; do
    if ! pwsh -NoProfile -Command "
        \$parseErrors = \$null; \$tokens = \$null
        [System.Management.Automation.Language.Parser]::ParseFile('$f', [ref]\$tokens, [ref]\$parseErrors) | Out-Null
        if (\$parseErrors) { exit 1 }
      " >/dev/null 2>&1; then
      echo "parse error: $f"
      fail=1
    fi
  done < <(find "$SKILL_DIR/scripts" -name '*.ps1' -print0)
else
  echo "note: pwsh not found — .ps1 parse-check skipped, .sh syntax check still ran"
fi

exit $fail
