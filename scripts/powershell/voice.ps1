# Partner Voice (HeyKoala connection + call history) — /v1/partner/voice/*.
# Usage: pwsh ./voice.ps1 connection options
#        pwsh ./voice.ps1 connection validate <apiKey>
#        pwsh ./voice.ps1 connection get
#        pwsh ./voice.ps1 connection update <agentId> <phoneNumberId> <callFlowId> [apiKey]
#        pwsh ./voice.ps1 connection rotate-key
#        pwsh ./voice.ps1 connection test <branchId> <date YYYY-MM-DD> <partySize>
#        pwsh ./voice.ps1 connection go-live
#        pwsh ./voice.ps1 connection delete
#        pwsh ./voice.ps1 calls list [key=value ...]
#        pwsh ./voice.ps1 calls stats [key=value ...]
#        pwsh ./voice.ps1 calls sync
#        pwsh ./voice.ps1 calls linked <reservationId|inquiryId> <id>
#        pwsh ./voice.ps1 calls get <callId>
#
# All routes use partner bearer auth. `calls linked` takes the xor key explicitly as its own
# argument (reservationId or inquiryId) rather than guessing from the id's shape.
param(
    [Parameter(Mandatory, Position = 0)][ValidateSet('connection', 'calls')][string]$Group,
    [Parameter(Position = 1)][string]$Sub,
    [Parameter(Position = 2, ValueFromRemainingArguments)][string[]]$Rest
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

if (-not $Sub) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: voice.ps1 connection <action> | calls <action> [args]' }
if (-not $Rest) { $Rest = @() }

function ConvertTo-GgQueryHashtable {
    param([string[]]$Pairs)
    $q = @{}
    foreach ($kv in $Pairs) {
        $parts = $kv -split '=', 2
        if ($parts.Count -eq 2) { $q[$parts[0]] = $parts[1] }
    }
    return $q
}

switch ($Group) {
    'connection' {
        switch ($Sub) {
            'options' { Get-GgVoiceConnectionOptions | ConvertFrom-Json | ConvertTo-Json -Depth 10 }
            'validate' {
                if (-not $Rest[0]) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: voice.ps1 connection validate <apiKey>' }
                Test-GgVoiceApiKey -ApiKey $Rest[0] | ConvertFrom-Json | ConvertTo-Json -Depth 10
            }
            'get' { Get-GgVoiceConnection | ConvertFrom-Json | ConvertTo-Json -Depth 10 }
            'update' {
                if ($Rest.Count -lt 3) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: voice.ps1 connection update <agentId> <phoneNumberId> <callFlowId> [apiKey]' }
                $params = @{ AgentId = $Rest[0]; PhoneNumberId = $Rest[1]; CallFlowId = $Rest[2] }
                if ($Rest.Count -ge 4 -and $Rest[3]) { $params['ApiKey'] = $Rest[3] }
                Set-GgVoiceConnection @params | ConvertFrom-Json | ConvertTo-Json -Depth 10
            }
            'rotate-key' { Update-GgVoiceToolKey | ConvertFrom-Json | ConvertTo-Json -Depth 10 }
            'test' {
                if ($Rest.Count -lt 3) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: voice.ps1 connection test <branchId> <date YYYY-MM-DD> <partySize>' }
                Test-GgVoiceConnection -BranchId $Rest[0] -Date $Rest[1] -PartySize ([int]$Rest[2]) | ConvertFrom-Json | ConvertTo-Json -Depth 10
            }
            'go-live' { Enable-GgVoiceLive | ConvertFrom-Json | ConvertTo-Json -Depth 10 }
            'delete' { Remove-GgVoiceConnection }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown connection subcommand: $Sub" }
        }
    }
    'calls' {
        switch ($Sub) {
            'list' { Get-GgVoiceCalls -Query (ConvertTo-GgQueryHashtable -Pairs $Rest) | ConvertFrom-Json | ConvertTo-Json -Depth 10 }
            'stats' { Get-GgVoiceCallStats -Query (ConvertTo-GgQueryHashtable -Pairs $Rest) | ConvertFrom-Json | ConvertTo-Json -Depth 10 }
            'sync' { Start-GgVoiceCallsSync | ConvertFrom-Json | ConvertTo-Json -Depth 10 }
            'linked' {
                if ($Rest.Count -lt 2 -or $Rest[0] -notin @('reservationId', 'inquiryId')) {
                    Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: voice.ps1 calls linked <reservationId|inquiryId> <id>'
                }
                Get-GgVoiceLinkedCall -LinkKey $Rest[0] -LinkId $Rest[1] | ConvertFrom-Json | ConvertTo-Json -Depth 10
            }
            'get' {
                if (-not $Rest[0]) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: voice.ps1 calls get <callId>' }
                Get-GgVoiceCall -CallId $Rest[0] | ConvertFrom-Json | ConvertTo-Json -Depth 10
            }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown calls subcommand: $Sub" }
        }
    }
}
