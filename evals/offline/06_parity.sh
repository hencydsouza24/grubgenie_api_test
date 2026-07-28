#!/usr/bin/env bash
# Every top-level scripts/*.sh must have a scripts/powershell/*.ps1 twin — full parity was
# chosen explicitly (2026-07-29), including the shim scripts. BLOCKING as of Phase 5 — all 16
# scripts have twins as of this check's introduction; a new bash script added without one now
# fails the suite immediately instead of silently drifting.
set -uo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0

while IFS= read -r -d '' f; do
  base="$(basename "$f" .sh)"
  pascal="$(tr '[:lower:]' '[:upper:]' <<< "${base:0:1}")${base:1}"
  if [ ! -f "$SKILL_DIR/scripts/powershell/${base}.ps1" ] && [ ! -f "$SKILL_DIR/scripts/powershell/${pascal}.ps1" ]; then
    echo "no PowerShell twin for scripts/${base}.sh"
    fail=1
  fi
done < <(find "$SKILL_DIR/scripts" -maxdepth 1 -name '*.sh' -print0)

exit $fail
