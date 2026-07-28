# Back-compat shim — see pos.ps1. Usage: pwsh ./branch_pos_config.ps1 setup|disable|get [provider]
param(
    [Parameter(Position = 0)][string]$Action = 'get',
    [Parameter(Position = 1)][string]$Provider
)
. "$PSScriptRoot/lib/Bootstrap.ps1"
if (-not $Provider) { $Provider = $Script:GgPosProvider }

switch ($Action) {
    'get' { Get-GgPosConfig }
    'setup' { Set-GgPosConfig }
    'disable' { Remove-GgPosConfig -Provider $Provider }
    default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: branch_pos_config.ps1 setup|disable|get [provider]' }
}
