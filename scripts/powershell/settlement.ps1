# Admin settlement operations — list/summarize/calculate/create/mark-settled settlements.
# Usage: pwsh ./settlement.ps1 admin list [key=value ...]
#        pwsh ./settlement.ps1 admin summary
#        pwsh ./settlement.ps1 admin partner <partnerId> [key=value ...]
#        pwsh ./settlement.ps1 admin branch <branchId> [key=value ...]
#        pwsh ./settlement.ps1 admin calculate <partnerId> <periodFrom> <periodTo> [branchId]
#        pwsh ./settlement.ps1 admin batch-calculate <periodFrom> <periodTo> <partnerId[:branchId]> [...]
#        pwsh ./settlement.ps1 admin create <partnerId> <periodFrom> <periodTo> [branchId] [notes]
#        pwsh ./settlement.ps1 admin batch-create <periodFrom> <periodTo> <partnerId[:branchId]> [...]
#        pwsh ./settlement.ps1 admin get <settlementId>
#        pwsh ./settlement.ps1 admin mark-settled <settlementId> [notes]
# periodFrom/periodTo are YYYY-MM-DD dates. Requires admin credentials (see
# scripts/config/credentials.example.env) — Get-GgCachedAdminToken lazily logs in and caches it.
#
# Arity varies a lot across subcommands (0 to many trailing key=value/target tokens), so unlike
# pos.ps1's fixed Command/Arg1/Arg2 params, every argument here is read positionally out of one
# captured array — $ArgList[0] is the bash twin's $1, and so on.
param(
    [Parameter(ValueFromRemainingArguments)][string[]]$ArgList = @()
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

$Usage = 'Usage: settlement.ps1 admin list|summary|partner|branch|calculate|batch-calculate|create|batch-create|get|mark-settled [args]'

# Get-GgTail <all> <start> → the slice from index $start onward, or an empty array if $start is
# past the end (PowerShell range slicing errors on a negative/out-of-bounds upper index).
function Get-GgTail {
    param([string[]]$All, [int]$Start)
    if ($All.Count -le $Start) { return @() }
    return $All[$Start..($All.Count - 1)]
}

function ConvertTo-GgQueryHashtable {
    param([string[]]$Pairs)
    $q = @{}
    foreach ($p in $Pairs) {
        if ($p -match '^([^=]+)=(.*)$') { $q[$Matches[1]] = $Matches[2] }
    }
    return $q
}

$Group = $ArgList[0]
if (-not $Group) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $Usage }
if ($Group -ne 'admin') { Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown command group: $Group (expected: admin)" }

$Sub = $ArgList[1]
if (-not $Sub) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $Usage }

switch ($Sub) {
    'list' {
        $resp = Get-GgSettlementList -Query (ConvertTo-GgQueryHashtable -Pairs (Get-GgTail -All $ArgList -Start 2))
    }
    'summary' {
        $resp = Get-GgSettlementSummary
    }
    'partner' {
        $partnerId = $ArgList[2]
        if (-not $partnerId) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: settlement.ps1 admin partner <partnerId> [key=value ...]' }
        $resp = Get-GgPartnerSettlements -PartnerId $partnerId -Query (ConvertTo-GgQueryHashtable -Pairs (Get-GgTail -All $ArgList -Start 3))
    }
    'branch' {
        $branchId = $ArgList[2]
        if (-not $branchId) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: settlement.ps1 admin branch <branchId> [key=value ...]' }
        $resp = Get-GgBranchSettlements -BranchId $branchId -Query (ConvertTo-GgQueryHashtable -Pairs (Get-GgTail -All $ArgList -Start 3))
    }
    'calculate' {
        $partnerId = $ArgList[2]; $periodFrom = $ArgList[3]; $periodTo = $ArgList[4]; $branchId = $ArgList[5]
        $usage = 'Usage: settlement.ps1 admin calculate <partnerId> <periodFrom> <periodTo> [branchId]'
        if (-not $partnerId -or -not $periodFrom -or -not $periodTo) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $usage }
        $resp = New-GgSettlementCalculation -PartnerId $partnerId -PeriodFrom $periodFrom -PeriodTo $periodTo -BranchId $branchId
    }
    'batch-calculate' {
        $periodFrom = $ArgList[2]; $periodTo = $ArgList[3]
        $targets = Get-GgTail -All $ArgList -Start 4
        $usage = 'Usage: settlement.ps1 admin batch-calculate <periodFrom> <periodTo> <partnerId[:branchId]> [...]'
        if (-not $periodFrom -or -not $periodTo -or $targets.Count -eq 0) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $usage }
        $resp = New-GgSettlementBatchCalculation -PeriodFrom $periodFrom -PeriodTo $periodTo -Targets $targets
    }
    'create' {
        $partnerId = $ArgList[2]; $periodFrom = $ArgList[3]; $periodTo = $ArgList[4]; $branchId = $ArgList[5]; $notes = $ArgList[6]
        $usage = 'Usage: settlement.ps1 admin create <partnerId> <periodFrom> <periodTo> [branchId] [notes]'
        if (-not $partnerId -or -not $periodFrom -or -not $periodTo) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $usage }
        $resp = New-GgSettlement -PartnerId $partnerId -PeriodFrom $periodFrom -PeriodTo $periodTo -BranchId $branchId -Notes $notes
    }
    'batch-create' {
        $periodFrom = $ArgList[2]; $periodTo = $ArgList[3]
        $targets = Get-GgTail -All $ArgList -Start 4
        $usage = 'Usage: settlement.ps1 admin batch-create <periodFrom> <periodTo> <partnerId[:branchId]> [...]'
        if (-not $periodFrom -or -not $periodTo -or $targets.Count -eq 0) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $usage }
        $resp = New-GgSettlementBatch -PeriodFrom $periodFrom -PeriodTo $periodTo -Targets $targets
    }
    'get' {
        $settlementId = $ArgList[2]
        if (-not $settlementId) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: settlement.ps1 admin get <settlementId>' }
        $resp = Get-GgSettlement -SettlementId $settlementId
    }
    'mark-settled' {
        $settlementId = $ArgList[2]; $notes = $ArgList[3]
        if (-not $settlementId) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: settlement.ps1 admin mark-settled <settlementId> [notes]' }
        $resp = Set-GgSettlementMarkSettled -SettlementId $settlementId -Notes $notes
    }
    default {
        Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown subcommand: $Sub. $Usage"
    }
}

$resp | ConvertFrom-Json | ConvertTo-Json -Depth 10
