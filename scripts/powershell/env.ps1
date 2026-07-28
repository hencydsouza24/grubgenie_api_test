# Usage: . ./env.ps1 [-Env local|dev|prod]  (dot-source so $env:BASE persists in your session)
param([string]$Env = 'local')
. "$PSScriptRoot/lib/Bootstrap.ps1"

$base = Resolve-GgBase -Name $Env
$env:BASE = $base
Write-Output $base
Write-GgInfo "Environment: $Env -> $base"
