# Back-compat shim — see pos.ps1. Usage: pwsh ./fetch_pos_items.ps1 [provider]
param([string]$Provider)
. "$PSScriptRoot/lib/Bootstrap.ps1"
if (-not $Provider) { $Provider = $Script:GgPosProvider }
Get-GgPosItems -Provider $Provider
