# Partner CRM — Guest sub-resources, Inquiry, Insights. All routes use partner bearer auth.
#
# Usage: pwsh ./crm.ps1 guest whatsapp-thread <guestId> [limit] [before]
#        pwsh ./crm.ps1 guest campaigns <guestId>
#        pwsh ./crm.ps1 guest inquiries <guestId>
#        pwsh ./crm.ps1 guest calls <guestId>
#        pwsh ./crm.ps1 guest engagement-summary <guestId>
#        pwsh ./crm.ps1 inquiry list [k=v ...]
#        pwsh ./crm.ps1 inquiry create <guestName> <guestPhone> <inquiryType> [summary]
#        pwsh ./crm.ps1 inquiry get <inquiryId>
#        pwsh ./crm.ps1 inquiry update <inquiryId> [guestName] [guestPhone] [inquiryType] [summary]
#        pwsh ./crm.ps1 inquiry delete <inquiryId>
#        pwsh ./crm.ps1 inquiry status <inquiryId> <status> [reservationId]
#        pwsh ./crm.ps1 insights order-graph-data [fromDate] [toDate]
#        pwsh ./crm.ps1 insights menu-performance-details [fromDate] [toDate]
#        pwsh ./crm.ps1 insights category-rollup [fromDate] [toDate]
#        pwsh ./crm.ps1 insights weekly <branchId>
#        pwsh ./crm.ps1 insights promote-dish <itemId>
#        pwsh ./crm.ps1 insights hourly-demand <branchId> [fromDate] [toDate]
#
# Pass '' for an optional positional field you want to skip while still setting a later one.
# menu-performance-details and category-rollup responses are NOT wrapped in `.result` — see the
# NOTE in lib/ApiPartnerCrm.ps1.
param(
    [Parameter(Mandatory, Position = 0)][ValidateSet('guest', 'inquiry', 'insights')][string]$Group,
    [Parameter(Mandatory, Position = 1)][string]$Sub,
    [Parameter(Position = 2)][string]$Arg1,
    [Parameter(Position = 3)][string]$Arg2,
    [Parameter(Position = 4)][string]$Arg3,
    [Parameter(Position = 5)][string]$Arg4,
    [Parameter(Position = 6)][string]$Arg5
)
. "$PSScriptRoot/lib/Bootstrap.ps1"
# ApiPartnerCrm.ps1 isn't wired into Bootstrap.ps1 yet — dot-sourced directly here until it is.

switch ($Group) {
    'guest' {
        if (-not $Arg1) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Usage: crm.ps1 guest $Sub <guestId> [args]" }
        $resp = switch ($Sub) {
            'whatsapp-thread' { Get-GgGuestWhatsappThread -GuestId $Arg1 -Limit $Arg2 -Before $Arg3 }
            'campaigns' { Get-GgGuestCampaigns -GuestId $Arg1 }
            'inquiries' { Get-GgGuestInquiries -GuestId $Arg1 }
            'calls' { Get-GgGuestCalls -GuestId $Arg1 }
            'engagement-summary' { Get-GgGuestEngagementSummary -GuestId $Arg1 }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown guest subcommand: $Sub" }
        }
        ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
    }
    'inquiry' {
        switch ($Sub) {
            'list' {
                $filters = @{}
                foreach ($kv in @($Arg1, $Arg2, $Arg3, $Arg4, $Arg5)) {
                    if ($kv -and $kv.Contains('=')) {
                        $parts = $kv -split '=', 2
                        $filters[$parts[0]] = $parts[1]
                    }
                }
                $resp = Get-GgInquiries -Filters $filters
                ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
            }
            'create' {
                if (-not $Arg1) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: crm.ps1 inquiry create <guestName> <guestPhone> <inquiryType> [summary]' }
                $resp = New-GgInquiry -GuestName $Arg1 -GuestPhone $Arg2 -InquiryType $Arg3 -Summary $Arg4
                ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
            }
            'get' {
                if (-not $Arg1) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: crm.ps1 inquiry get <inquiryId>' }
                $resp = Get-GgInquiry -InquiryId $Arg1
                ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
            }
            'update' {
                if (-not $Arg1) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: crm.ps1 inquiry update <inquiryId> [guestName] [guestPhone] [inquiryType] [summary]' }
                $resp = Update-GgInquiry -InquiryId $Arg1 -GuestName $Arg2 -GuestPhone $Arg3 -InquiryType $Arg4 -Summary $Arg5
                ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
            }
            'delete' {
                if (-not $Arg1) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: crm.ps1 inquiry delete <inquiryId>' }
                Remove-GgInquiry -InquiryId $Arg1 | Out-Null
                Write-GgInfo "Inquiry $Arg1 deleted"
            }
            'status' {
                if (-not $Arg1 -or -not $Arg2) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: crm.ps1 inquiry status <inquiryId> <status> [reservationId]' }
                $resp = Set-GgInquiryStatus -InquiryId $Arg1 -Status $Arg2 -ReservationId $Arg3
                ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
            }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown inquiry subcommand: $Sub" }
        }
    }
    'insights' {
        switch ($Sub) {
            'order-graph-data' {
                $resp = Get-GgInsightsOrderGraphData -FromDate $Arg1 -ToDate $Arg2
                ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
            }
            'menu-performance-details' {
                # NOT wrapped in `.result` — see the NOTE in lib/ApiPartnerCrm.ps1.
                $resp = Get-GgInsightsMenuPerformanceDetails -FromDate $Arg1 -ToDate $Arg2
                ($resp | ConvertFrom-Json).data | ConvertTo-Json -Depth 10
            }
            'category-rollup' {
                # NOT wrapped in `.result` — see the NOTE in lib/ApiPartnerCrm.ps1.
                $resp = Get-GgInsightsCategoryRollup -FromDate $Arg1 -ToDate $Arg2
                ($resp | ConvertFrom-Json).data | ConvertTo-Json -Depth 10
            }
            'weekly' {
                if (-not $Arg1) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: crm.ps1 insights weekly <branchId>' }
                $resp = Get-GgInsightsWeekly -BranchId $Arg1
                ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
            }
            'promote-dish' {
                if (-not $Arg1) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: crm.ps1 insights promote-dish <itemId>' }
                $resp = Invoke-GgPromoteDish -ItemId $Arg1
                ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
            }
            'hourly-demand' {
                if (-not $Arg1) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: crm.ps1 insights hourly-demand <branchId> [fromDate] [toDate]' }
                $resp = Get-GgInsightsHourlyDemand -BranchId $Arg1 -FromDate $Arg2 -ToDate $Arg3
                ($resp | ConvertFrom-Json).result | ConvertTo-Json -Depth 10
            }
            default { Exit-GgDie -ExitCode $Script:GgExitUsage -Message "Unknown insights subcommand: $Sub" }
        }
    }
}
