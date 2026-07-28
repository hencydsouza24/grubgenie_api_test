#!/usr/bin/env bash
# Blocking secret gate. These exact values were committed to a PUBLIC repo and rotated on
# 2026-07-29 — this check exists so they (or their replacements) can never silently reappear.
set -uo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0

PATTERNS=(
  '1c54ca0d1f1f84bc9bfec49b9a2efd7852bdef59' # old Petpooja appSecret
  'c6038984b2ce7e1797f7ddc5b73641e1add36bf4' # old Petpooja accessToken
  'grubgod123'                                # old admin password (hello@grubgenie.ai)
)

for p in "${PATTERNS[@]}"; do
  while IFS= read -r f; do
    echo "FAIL: leaked secret shape found in $f"
    fail=1
  done < <(grep -rl -F "$p" "$SKILL_DIR" \
             --exclude-dir=.git --exclude-dir=node_modules \
             --exclude='credentials.env' --exclude='05_no_secrets.sh' 2>/dev/null)
done

# Structural gate: credentials.env must never be tracked by git, whether or not it currently
# exists on disk.
if git -C "$SKILL_DIR" ls-files --error-unmatch scripts/config/credentials.env >/dev/null 2>&1; then
  echo "FAIL: scripts/config/credentials.env is tracked by git — it must stay gitignored"
  fail=1
fi

exit $fail
