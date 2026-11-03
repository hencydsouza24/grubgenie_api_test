# Non-admin-bearer long-tail ops/diagnostic groups: the agents module, debug health/connections,
# the WhatsApp click redirect, and the voice tool webhook.
#
# Usage: pwsh ./misc_tools.ps1 <command> [args...]
#
# Commands: mirrors misc_tools.sh — see that file's header for the full list. voice-webhook's
# trailing key=value pairs become query params, e.g.:
#   pwsh ./misc_tools.ps1 voice-webhook availability partnerId=... branchId=... date=... partySize=...
param(
    [Parameter(Position = 0)][string]$Command,
    [Parameter(Position = 1)][string]$Action,
    [Parameter(Position = 2)][string]$Arg1,
    [Parameter(Position = 3)][string]$Arg2,
    [Parameter(Position = 4, ValueFromRemainingArguments = $true)][string[]]$Rest
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

$Usage = 'Usage: misc_tools.ps1 agents topic <topicKey> <partnerId> [branchId] | agents partner-info <partnerId> [branchId] | debug health | debug connections | redirect <buttonIndex> <ref> | voice-webhook <tool> [key=value ...]'

if (-not $Command) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $Usage }

switch ($Command) {
    'agents' {
        switch ($Action) {
            'topic'         { Get-GgAgentsTopic -TopicKey $Arg1 -PartnerId $Arg2 -BranchId ($Rest | Select-Object -First 1) }
            'partner-info'  { Get-GgAgentsPartnerInfo -PartnerId $Arg1 -BranchId $Arg2 }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: misc_tools.ps1 agents topic <topicKey> <partnerId> [branchId] | partner-info <partnerId> [branchId]' }
        }
    }
    'debug' {
        switch ($Action) {
            'health'      { Get-GgDebugHealth }
            'connections' { Get-GgDebugConnections }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: misc_tools.ps1 debug health|connections' }
        }
    }
    'redirect' {
        Invoke-GgRedirect -ButtonIndex $Action -Ref $Arg1
    }
    'voice-webhook' {
        if (-not $Action) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: misc_tools.ps1 voice-webhook <tool> [key=value ...]' }
        $pairs = @($Arg1, $Arg2) + $Rest | Where-Object { $_ }
        $params = @{}
        foreach ($pair in $pairs) {
            $kv = $pair -split '=', 2
            if ($kv.Count -eq 2) { $params[$kv[0]] = $kv[1] }
        }
        Invoke-GgVoiceToolWebhook -Tool $Action -Params $params
    }
    default {
        Exit-GgDie -ExitCode $Script:GgExitUsage -Message $Usage
    }
}
