# Admin partner management — list/view/patch partners, read and update branch agent contexts.
# Usage: pwsh ./admin_partner.ps1 list [key=value ...]
#        pwsh ./admin_partner.ps1 get <accountId>
#        pwsh ./admin_partner.ps1 patch <accountId> <key=value> [key=value ...]
#        pwsh ./admin_partner.ps1 agent-contexts
#        pwsh ./admin_partner.ps1 branch-contexts <accountId>
#        pwsh ./admin_partner.ps1 branch-context get <accountId> <branchId>
#        pwsh ./admin_partner.ps1 branch-context put <accountId> <branchId> <context>
# The path param is accountId, NOT partnerId (the partner.info module keys partners by
# accountId). Requires admin credentials (see scripts/config/credentials.example.env) —
# Get-GgCachedAdminToken lazily logs in and caches it.
#
# Arity varies across subcommands, so every argument is read positionally out of one captured
# array instead of pos.ps1-style named Arg1/Arg2 params — $ArgList[0] is the bash twin's $1.
param(
    [Parameter(ValueFromRemainingArguments)][string[]]$ArgList = @()
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

$Usage = 'Usage: admin_partner.ps1 list|get|patch|agent-contexts|branch-contexts|branch-context [args]'

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

$Command = $ArgList[0]
if (-not $Command) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $Usage }

switch ($Command) {
    'list' {
        $resp = Get-GgAdminPartners -Query (ConvertTo-GgQueryHashtable -Pairs (Get-GgTail -All $ArgList -Start 1))
    }
    'get' {
        $accountId = $ArgList[1]
        if (-not $accountId) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_partner.ps1 get <accountId>' }
        $resp = Get-GgAdminPartner -AccountId $accountId
    }
    'patch' {
        $accountId = $ArgList[1]
        $pairs = Get-GgTail -All $ArgList -Start 2
        if (-not $accountId -or $pairs.Count -eq 0) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_partner.ps1 patch <accountId> <key=value> [key=value ...]' }
        $resp = Update-GgAdminPartner -AccountId $accountId -Fields (ConvertTo-GgQueryHashtable -Pairs $pairs)
    }
    'agent-contexts' {
        $resp = Get-GgAllBranchAgentContexts
    }
    'branch-contexts' {
        $accountId = $ArgList[1]
        if (-not $accountId) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_partner.ps1 branch-contexts <accountId>' }
        $resp = Get-GgPartnerBranchAgentContexts -AccountId $accountId
    }
    'branch-context' {
        $sub = $ArgList[1]
        $branchContextUsage = 'Usage: admin_partner.ps1 branch-context get|put <accountId> <branchId> [context]'
        if (-not $sub) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $branchContextUsage }
        switch ($sub) {
            'get' {
                $accountId = $ArgList[2]; $branchId = $ArgList[3]
                if (-not $accountId -or -not $branchId) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_partner.ps1 branch-context get <accountId> <branchId>' }
                $resp = Get-GgBranchAgentContext -AccountId $accountId -BranchId $branchId
            }
            'put' {
                $accountId = $ArgList[2]; $branchId = $ArgList[3]; $context = $ArgList[4]
                if (-not $accountId -or -not $branchId -or -not $context) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: admin_partner.ps1 branch-context put <accountId> <branchId> <context>' }
                $resp = Set-GgBranchAgentContext -AccountId $accountId -BranchId $branchId -Context $context
            }
            default {
                Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown branch-context subcommand: $sub. $branchContextUsage"
            }
        }
    }
    default {
        Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown command: $Command. $Usage"
    }
}

$resp | ConvertFrom-Json | ConvertTo-Json -Depth 10
