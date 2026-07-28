# Back-compat shim — see pos.ps1. Usage: pwsh ./get_pos_menu.ps1 [provider]
param([string]$Provider)
. "$PSScriptRoot/lib/Bootstrap.ps1"
if (-not $Provider) { $Provider = $Script:GgPosProvider }
Get-GgPosMenu -Provider $Provider
