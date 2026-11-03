# Admin Genie — fleet/session inspection and per-thread control (signal, chat, evict, end).
# Usage: pwsh ./genie_admin.ps1 fleet
#        pwsh ./genie_admin.ps1 sessions [page] [limit] [fromTimestamp] [toTimestamp]
#        pwsh ./genie_admin.ps1 thread get <threadId>
#        pwsh ./genie_admin.ps1 thread activity <threadId> [limit]
#        pwsh ./genie_admin.ps1 thread evict <threadId>
#        pwsh ./genie_admin.ps1 thread signal <threadId> <type> [payloadJson]
#        pwsh ./genie_admin.ps1 thread chat <threadId> <message>
#        pwsh ./genie_admin.ps1 thread end <threadId>
#        pwsh ./genie_admin.ps1 spawn <dinerId> <cartId> <branchId> <accountId> <partnerId> <tableId>
# threadId is a composite "diner-agent:<cartId>:<dinerId>" (see buildThreadId in
# src/modules/genieV2/genie.helpers.ts) — build it from a spawned session's cartId/dinerId.
# Requires admin credentials (see scripts/config/credentials.example.env) —
# Get-GgCachedAdminToken lazily logs in and caches it.
#
# Every argument is read positionally out of one captured array instead of pos.ps1-style named
# Arg1/Arg2 params, since arity varies a lot (0 to 6 trailing args) — $ArgList[0] is the bash
# twin's $1.
param(
    [Parameter(ValueFromRemainingArguments)][string[]]$ArgList = @()
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

$Usage = 'Usage: genie_admin.ps1 fleet|sessions|thread|spawn [args]'

$Command = $ArgList[0]
if (-not $Command) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $Usage }

switch ($Command) {
    'fleet' {
        $resp = Get-GgGenieFleet
    }
    'sessions' {
        $resp = Get-GgGenieSessions -Page $ArgList[1] -Limit $ArgList[2] -FromTimestamp $ArgList[3] -ToTimestamp $ArgList[4]
    }
    'thread' {
        $sub = $ArgList[1]
        $threadId = $ArgList[2]
        $threadUsage = 'Usage: genie_admin.ps1 thread get|activity|evict|signal|chat|end <threadId> [args]'
        if (-not $sub) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $threadUsage }
        if (-not $threadId) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Usage: genie_admin.ps1 thread $sub <threadId> [args]" }

        switch ($sub) {
            'get' {
                $resp = Get-GgGenieThread -ThreadId $threadId
            }
            'activity' {
                $resp = Get-GgGenieThreadActivity -ThreadId $threadId -Limit $ArgList[3]
            }
            'evict' {
                $resp = Remove-GgGenieThread -ThreadId $threadId
            }
            'signal' {
                $signalType = $ArgList[3]; $payload = $ArgList[4]
                if (-not $signalType) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: genie_admin.ps1 thread signal <threadId> <type> [payloadJson]' }
                if ($payload) {
                    $resp = Send-GgGenieThreadSignal -ThreadId $threadId -SignalType $signalType -PayloadJson $payload
                }
                else {
                    $resp = Send-GgGenieThreadSignal -ThreadId $threadId -SignalType $signalType
                }
            }
            'chat' {
                $message = $ArgList[3]
                if (-not $message) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: genie_admin.ps1 thread chat <threadId> <message>' }
                $resp = Send-GgGenieChatMessage -ThreadId $threadId -Message $message
            }
            'end' {
                $resp = Stop-GgGenieThread -ThreadId $threadId
            }
            default {
                Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown thread subcommand: $sub. $threadUsage"
            }
        }
    }
    'spawn' {
        $dinerId = $ArgList[1]; $cartId = $ArgList[2]; $branchId = $ArgList[3]; $accountId = $ArgList[4]; $partnerId = $ArgList[5]; $tableId = $ArgList[6]
        $spawnUsage = 'Usage: genie_admin.ps1 spawn <dinerId> <cartId> <branchId> <accountId> <partnerId> <tableId>'
        if (-not $dinerId -or -not $cartId -or -not $branchId -or -not $accountId -or -not $partnerId -or -not $tableId) {
            Exit-GgDie -ExitCode $Script:GgExitUsage -Message $spawnUsage
        }
        $resp = New-GgGenieSession -DinerId $dinerId -CartId $cartId -BranchId $branchId -AccountId $accountId -PartnerId $partnerId -TableId $tableId
    }
    default {
        Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown command: $Command. $Usage"
    }
}

$resp | ConvertFrom-Json | ConvertTo-Json -Depth 10
