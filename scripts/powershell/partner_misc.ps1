# Partner misc reads: active order by table, WhatsApp agent settings + audience segments, and
# the front-desk report (with optional XLSX export).
# Usage: pwsh ./partner_misc.ps1 active-order <tableId>
#        pwsh ./partner_misc.ps1 agent-settings get
#        pwsh ./partner_misc.ps1 agent-settings update <field> <value>
#        pwsh ./partner_misc.ps1 audience-segments
#        pwsh ./partner_misc.ps1 front-desk-report [-Export] <from> <to> [scope] [branchId]
param(
    [Parameter(Mandatory, Position = 0)][ValidateSet('active-order', 'agent-settings', 'audience-segments', 'front-desk-report')][string]$Command,
    [Parameter(Position = 1)][string]$Arg1,
    [Parameter(Position = 2)][string]$Arg2,
    [Parameter(Position = 3)][string]$Arg3,
    [Parameter(Position = 4)][string]$Arg4,
    [switch]$Export
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

switch ($Command) {
    'active-order' {
        if (-not $Arg1) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_misc.ps1 active-order <tableId>' }
        Get-GgActiveOrderByTable -TableId $Arg1
    }
    'agent-settings' {
        $sub = if ($Arg1) { $Arg1 } else { 'get' }
        switch ($sub) {
            'get' { Get-GgWhatsappAgentSettings }
            'update' {
                if (-not $Arg2) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_misc.ps1 agent-settings update <field> <value>' }
                Set-GgWhatsappAgentSettings -Field $Arg2 -Value $Arg3
            }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_misc.ps1 agent-settings get|update [args]' }
        }
    }
    'audience-segments' {
        Get-GgWhatsappAudienceSegments
    }
    'front-desk-report' {
        # When -Export isn't a leading switch on the CLI, allow `front-desk-report <from> <to> --export`
        # as well by treating a literal "--export"/"-export" positional as the flag too.
        $from = $Arg1
        $to = $Arg2
        $scope = if ($Arg3) { $Arg3 } else { 'single' }
        $branchId = $Arg4

        if (-not $from) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_misc.ps1 front-desk-report [-Export] <from> <to> [scope] [branchId]' }
        if (-not $to) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: partner_misc.ps1 front-desk-report [-Export] <from> <to> [scope] [branchId]' }

        if ($Export) {
            $outFile = "front-desk-report-$from-to-$to.xlsx"
            $bytes = Export-GgFrontDeskReport -From $from -To $to -Scope $scope -BranchId $branchId
            [System.IO.File]::WriteAllText($outFile, $bytes)
            Write-GgInfo "Saved: $outFile"
        }
        else {
            Get-GgFrontDeskReport -From $from -To $to -Scope $scope -BranchId $branchId
        }
    }
}
