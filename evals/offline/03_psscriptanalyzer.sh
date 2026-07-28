#!/usr/bin/env bash
# PSScriptAnalyzer (Severity Error only — style/verb-naming warnings are informational, not
# gating, since this is a script toolkit, not a published module). Exit: 2 (skip) if pwsh or the
# module isn't available.
set -uo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v pwsh >/dev/null 2>&1; then
  echo "pwsh not installed"
  exit 2
fi

if ! pwsh -NoProfile -Command "if (Get-Module -ListAvailable PSScriptAnalyzer) { exit 0 } else { exit 1 }" >/dev/null 2>&1; then
  echo "PSScriptAnalyzer module not installed (Install-Module PSScriptAnalyzer)"
  exit 2
fi

pwsh -NoProfile -Command "
  Import-Module PSScriptAnalyzer
  \$results = Get-ChildItem -Path '$SKILL_DIR/scripts' -Recurse -Filter *.ps1 |
    ForEach-Object { Invoke-ScriptAnalyzer -Path \$_.FullName -Severity Error }
  if (\$results) { \$results | Format-Table -AutoSize | Out-String | Write-Host; exit 1 } else { exit 0 }
"
