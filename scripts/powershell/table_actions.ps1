# Table split/merge/chair-borrow actions — additional to the basic list/status-update ops already
# covered by reset_tables.ps1 and Get-GgTables/Set-GgTableStatus in lib/Api.ps1.
# Usage: pwsh ./table_actions.ps1 split <tableId> <seg1> <seg2> [seg3] [seg4]
#        pwsh ./table_actions.ps1 merge <tableId>
#        pwsh ./table_actions.ps1 borrow-chair <tableId> <fromTableId> [count]
#        pwsh ./table_actions.ps1 return-chair <tableId> <borrowId>
#
# return-chair's route is DELETE /v1/partner/table/:tableId/borrow-chair/:borrowId — both the
# table and the specific borrow record's own id are path params (confirmed against
# table.route.ts); borrowId is the `_id` of an entry in `.result.borrowedChairs[]` returned by a
# prior `borrow-chair` call.
param(
    [Parameter(Mandatory, Position = 0)][ValidateSet('split', 'merge', 'borrow-chair', 'return-chair')][string]$Command,
    [Parameter(Position = 1)][string]$TableId,
    [Parameter(Position = 2, ValueFromRemainingArguments)][string[]]$Rest
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

$usage = 'Usage: table_actions.ps1 split <tableId> <seg1> <seg2> [seg3] [seg4] | merge <tableId> | borrow-chair <tableId> <fromTableId> [count] | return-chair <tableId> <borrowId>'
if (-not $TableId) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $usage }
if (-not $Rest) { $Rest = @() }

switch ($Command) {
    'split' {
        if ($Rest.Count -lt 2) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $usage }
        $segments = $Rest | ForEach-Object { [int]$_ }
        Split-GgTable -TableId $TableId -Segments $segments | ConvertFrom-Json | ConvertTo-Json -Depth 10
    }
    'merge' {
        Merge-GgTable -TableId $TableId | ConvertFrom-Json | ConvertTo-Json -Depth 10
    }
    'borrow-chair' {
        if ($Rest.Count -lt 1) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $usage }
        $params = @{ TableId = $TableId; FromTableId = $Rest[0] }
        if ($Rest.Count -ge 2 -and $Rest[1]) { $params['Count'] = [int]$Rest[1] }
        Invoke-GgBorrowChair @params | ConvertFrom-Json | ConvertTo-Json -Depth 10
    }
    'return-chair' {
        if ($Rest.Count -lt 1) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message $usage }
        Remove-GgBorrowedChair -TableId $TableId -BorrowId $Rest[0] | ConvertFrom-Json | ConvertTo-Json -Depth 10
    }
}
