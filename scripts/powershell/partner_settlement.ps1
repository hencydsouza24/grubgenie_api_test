# Partner Settlement reads (read-only, partner bearer auth).
# Usage: pwsh ./partner_settlement.ps1 list [k=v ...]
#        pwsh ./partner_settlement.ps1 summary
#
# k=v filters for `list`: branchId, status, gateway, periodFrom, periodTo, sortBy, page, limit
# (listPartnerSettlements query schema). branchId is auto-scoped server-side for non-admin
# partner users, so it's rarely needed here.
param(
    [Parameter(Mandatory, Position = 0)][ValidateSet('list', 'summary')][string]$Command,
    [Parameter(Position = 1)][string]$Arg1,
    [Parameter(Position = 2)][string]$Arg2,
    [Parameter(Position = 3)][string]$Arg3,
    [Parameter(Position = 4)][string]$Arg4,
    [Parameter(Position = 5)][string]$Arg5
)
. "$PSScriptRoot/lib/Bootstrap.ps1"
# ApiPartnerCatalog.ps1 isn't wired into Bootstrap.ps1 yet — dot-sourced directly here until it is.

switch ($Command) {
    'list' {
        $filters = @{}
        foreach ($kv in @($Arg1, $Arg2, $Arg3, $Arg4, $Arg5)) {
            if ($kv -and $kv.Contains('=')) {
                $parts = $kv -split '=', 2
                $filters[$parts[0]] = $parts[1]
            }
        }
        $resp = Get-GgSettlements -Filters $filters
        ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
    }
    'summary' {
        $resp = Get-GgPartnerSettlementSummary
        ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
    }
}
