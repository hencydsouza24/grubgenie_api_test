# Test the GrubGenie agent chat endpoint (unauthenticated — no session required).
# Usage: pwsh ./agent_test.ps1 "<message>" [-DinerId <id>]
param(
    [Parameter(Mandatory, Position = 0)][string]$Message,
    [string]$DinerId
)
. "$PSScriptRoot/lib/Bootstrap.ps1"
if (-not $DinerId) { $DinerId = $Script:GgDinerTest }

$body = New-GgJsonObj @{ message = $Message }
$resp = Invoke-GgHttpOrDie -Label 'agent chat' -Method POST -Path "/v1/test/agent-chat/$DinerId" -JsonBody $body
Write-Output ($resp | ConvertFrom-Json | ConvertTo-Json -Depth 10)
