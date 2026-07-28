# Back-compat shim — see pos.ps1. Usage: pwsh ./sync_pos_menu.ps1 [provider]
param([string]$Provider)
. "$PSScriptRoot/lib/Bootstrap.ps1"
if (-not $Provider) { $Provider = $Script:GgPosProvider }
$resp = Start-GgPosSync -Provider $Provider
$resp | ConvertFrom-Json | ConvertTo-Json -Depth 5
