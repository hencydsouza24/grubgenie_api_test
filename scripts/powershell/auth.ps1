# Usage: . ./auth.ps1 [-Force]  (dot-source so the exported vars persist in your session)
# Authenticates (idempotently — reuses a session younger than GgSessionTtl seconds) and sets
# $env:BASE, $env:PARTNER_TOKEN, $env:TABLE_ID, $env:DINER_TOKEN, $env:DINER_ID.
param([switch]$Force)
. "$PSScriptRoot/lib/Bootstrap.ps1"

$path = Confirm-GgSession -Force:$Force
$session = Get-Content $path -Raw | ConvertFrom-Json

$env:BASE = $session.base
$env:PARTNER_TOKEN = $session.partnerToken
$env:TABLE_ID = $session.tableId
$env:DINER_TOKEN = $session.dinerToken
$env:DINER_ID = $session.dinerId
# Confirm-GgSession already prints Partner token/Table/Diner when it performs a fresh auth (see
# Auth.ps1) — no need to repeat it here.
