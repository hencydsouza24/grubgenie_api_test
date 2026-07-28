#!/usr/bin/env bash
# House-style conventions, enforced mechanically instead of by memory.
#
# Scope is SELF-WIDENING, not a maintained list: a script is "in scope" once it's migrated to
# source the shared lib (lib/bootstrap.sh or lib/Bootstrap.ps1) — everything under lib/ itself is
# always in scope. Legacy scripts the refactor hasn't reached yet are simply out of scope until
# they adopt the lib, so this gate can be blocking from Phase 1 without waiting for Phase 6.
set -uo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0

fail_check() { echo "FAIL: $1"; fail=1; }

migrated_bash_files() {
  find "$SKILL_DIR/scripts/lib" -name '*.sh' -print0 2>/dev/null
  find "$SKILL_DIR/scripts" -maxdepth 1 -name '*.sh' -print0 2>/dev/null |
    xargs -0 -I{} sh -c 'grep -q "lib/bootstrap.sh" "{}" 2>/dev/null && printf "%s\0" "{}"'
}

migrated_ps_files() {
  find "$SKILL_DIR/scripts/powershell/lib" -name '*.ps1' -print0 2>/dev/null
  find "$SKILL_DIR/scripts/powershell" -maxdepth 1 -name '*.ps1' -print0 2>/dev/null |
    xargs -0 -I{} sh -c 'grep -q "lib/Bootstrap.ps1" "{}" 2>/dev/null && printf "%s\0" "{}"'
}

# Shebang uniformity (bash side only — PowerShell has no shebang convention here).
while IFS= read -r -d '' f; do
  head -1 "$f" | grep -qx '#!/usr/bin/env bash' || fail_check "non-uniform shebang: $f"
done < <(migrated_bash_files)

# No bare curl outside lib/http.sh — everything else must go through gg_http. Comment lines
# (e.g. "no raw curl here") are excluded so prose mentioning curl doesn't self-trigger this.
while IFS= read -r -d '' f; do
  case "$f" in */lib/http.sh) continue ;; esac
  grep -v '^\s*#' "$f" 2>/dev/null | grep -q '\bcurl ' && fail_check "bare curl outside lib/http.sh: $f"
done < <(migrated_bash_files)

# No BASE_URL — the one true name is BASE (test_pos_validation.sh used to diverge here).
while IFS= read -r f; do
  fail_check "uses BASE_URL instead of BASE: $f"
done < <(grep -rl 'BASE_URL' "$SKILL_DIR/scripts/lib" 2>/dev/null)

# No `head -n -1` — illegal on BSD/macOS head; broke sync_pos_menu.sh in the old implementation.
while IFS= read -r f; do
  fail_check "head -n -1 (broken on macOS): $f"
done < <(grep -rl -- '-n -1' "$SKILL_DIR/scripts/lib" --include='*.sh' 2>/dev/null)

# No shell string-interpolated JSON bodies (`-d "{\"...`) — breaks on quotes/backslashes and is
# the exact mechanism that let a null token become a syntactically valid request.
while IFS= read -r f; do
  fail_check "string-interpolated JSON body: $f"
done < <(grep -rlE -- '-d "\{\\"' "$SKILL_DIR/scripts/lib" 2>/dev/null)

# PowerShell: hand-built JSON string literals instead of ConvertTo-Json/New-GgJsonObj.
while IFS= read -r -d '' f; do
  case "$f" in */lib/Http.ps1|*/lib/Json.ps1) continue ;; esac
  grep -Eq -- '-JsonBody "\{' "$f" 2>/dev/null && fail_check "hand-built JSON string in PowerShell: $f"
done < <(migrated_ps_files)

exit $fail
