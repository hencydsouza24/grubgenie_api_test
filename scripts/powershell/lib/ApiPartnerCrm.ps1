# Partner CRM domain verbs — Guest sub-resources, Inquiry, Insights. Mirrors
# scripts/lib/api_partner_crm.sh function-for-function. Intended to be dot-sourced by
# Bootstrap.ps1 once wired in centrally; until then, crm.ps1 dot-sources it directly, right after
# lib/Bootstrap.ps1.
#
#   gg_guest_whatsapp_thread             -> Get-GgGuestWhatsappThread
#   gg_guest_campaigns                   -> Get-GgGuestCampaigns
#   gg_guest_inquiries                   -> Get-GgGuestInquiries
#   gg_guest_calls                       -> Get-GgGuestCalls
#   gg_guest_engagement_summary          -> Get-GgGuestEngagementSummary
#   gg_inquiry_list                      -> Get-GgInquiries
#   gg_inquiry_create                    -> New-GgInquiry
#   gg_inquiry_get                       -> Get-GgInquiry
#   gg_inquiry_update                    -> Update-GgInquiry
#   gg_inquiry_delete                    -> Remove-GgInquiry
#   gg_inquiry_set_status                -> Set-GgInquiryStatus
#   gg_insights_order_graph_data         -> Get-GgInsightsOrderGraphData
#   gg_insights_menu_performance_details -> Get-GgInsightsMenuPerformanceDetails
#   gg_insights_category_rollup          -> Get-GgInsightsCategoryRollup
#   gg_insights_weekly                   -> Get-GgInsightsWeekly
#   gg_insights_promote_dish             -> Invoke-GgPromoteDish
#   gg_insights_hourly_demand            -> Get-GgInsightsHourlyDemand

if (Get-Variable -Name _GgApiPartnerCrmLoaded -Scope Script -ErrorAction SilentlyContinue) { return }
$Script:_GgApiPartnerCrmLoaded = $true

# --- Guest sub-resources (/v1/partner/guests/:guestId/...) ---
#
# Base Guest CRUD predates this file and lives elsewhere — these are only the 5 NEW read-only
# sub-resources. Route base is `/v1/partner/guests` (plural) — confirmed against
# src/routes/v1/partner/index.ts, which mounts guest.route.ts at `/guests`, not `/guest`.

function Get-GgGuestWhatsappThread {
    param([Parameter(Mandatory)][string]$GuestId, [string]$Limit, [string]$Before)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $query = @{}
    if ($Limit) { $query['limit'] = $Limit }
    if ($Before) { $query['before'] = $Before }
    return Invoke-GgHttpOrDie -Label 'guest whatsapp thread' -Method GET -Path "$base/v1/partner/guests/$GuestId/whatsapp-thread" -Token $partnerToken -Query $query
}

function Get-GgGuestCampaigns {
    param([Parameter(Mandatory)][string]$GuestId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'guest campaigns' -Method GET -Path "$base/v1/partner/guests/$GuestId/campaigns" -Token $partnerToken
}

function Get-GgGuestInquiries {
    param([Parameter(Mandatory)][string]$GuestId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'guest inquiries' -Method GET -Path "$base/v1/partner/guests/$GuestId/inquiries" -Token $partnerToken
}

function Get-GgGuestCalls {
    param([Parameter(Mandatory)][string]$GuestId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'guest calls' -Method GET -Path "$base/v1/partner/guests/$GuestId/calls" -Token $partnerToken
}

function Get-GgGuestEngagementSummary {
    param([Parameter(Mandatory)][string]$GuestId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'guest engagement summary' -Method GET -Path "$base/v1/partner/guests/$GuestId/engagement-summary" -Token $partnerToken
}

# --- Inquiry (/v1/partner/inquiry) ---

# Get-GgInquiries [-Filters @{status='open'; limit=5}] — any listInquiries query filters, passed
# through verbatim.
function Get-GgInquiries {
    param([hashtable]$Filters = @{})
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'inquiry list' -Method GET -Path "$base/v1/partner/inquiry" -Token $partnerToken -Query $Filters
}

function New-GgInquiry {
    param(
        [Parameter(Mandatory)][string]$GuestName,
        [Parameter(Mandatory)][string]$GuestPhone,
        [Parameter(Mandatory)][string]$InquiryType,
        [string]$Summary
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $fields = @{ guestName = $GuestName; guestPhone = $GuestPhone; inquiryType = $InquiryType }
    if ($Summary) { $fields['summary'] = $Summary }
    $body = $fields | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'inquiry create' -Method POST -Path "$base/v1/partner/inquiry" -Token $partnerToken -JsonBody $body
}

function Get-GgInquiry {
    param([Parameter(Mandatory)][string]$InquiryId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'inquiry get' -Method GET -Path "$base/v1/partner/inquiry/$InquiryId" -Token $partnerToken
}

# Update-GgInquiry <inquiryId> [-GuestName] [-GuestPhone] [-InquiryType] [-Summary] — the API
# requires at least one field in the body.
function Update-GgInquiry {
    param(
        [Parameter(Mandatory)][string]$InquiryId,
        [string]$GuestName, [string]$GuestPhone, [string]$InquiryType, [string]$Summary
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $fields = @{}
    if ($GuestName) { $fields['guestName'] = $GuestName }
    if ($GuestPhone) { $fields['guestPhone'] = $GuestPhone }
    if ($InquiryType) { $fields['inquiryType'] = $InquiryType }
    if ($Summary) { $fields['summary'] = $Summary }
    $body = $fields | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'inquiry update' -Method PUT -Path "$base/v1/partner/inquiry/$InquiryId" -Token $partnerToken -JsonBody $body
}

function Remove-GgInquiry {
    param([Parameter(Mandatory)][string]$InquiryId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'inquiry delete' -Method DELETE -Path "$base/v1/partner/inquiry/$InquiryId" -Token $partnerToken
}

# Set-GgInquiryStatus <inquiryId> <status> [-ReservationId] — route is
# POST /v1/partner/inquiry/:inquiryId/status (confirmed against inquiry.route.ts).
function Set-GgInquiryStatus {
    param(
        [Parameter(Mandatory)][string]$InquiryId,
        [Parameter(Mandatory)][string]$Status,
        [string]$ReservationId
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $fields = @{ status = $Status }
    if ($ReservationId) { $fields['reservationId'] = $ReservationId }
    $body = $fields | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'inquiry set status' -Method POST -Path "$base/v1/partner/inquiry/$InquiryId/status" -Token $partnerToken -JsonBody $body
}

# --- Insights (/v1/partner/insights) ---

function Get-GgInsightsOrderGraphData {
    param([string]$FromDate, [string]$ToDate)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $query = @{}
    if ($FromDate) { $query['fromDate'] = $FromDate }
    if ($ToDate) { $query['toDate'] = $ToDate }
    return Invoke-GgHttpOrDie -Label 'insights order graph data' -Method GET -Path "$base/v1/partner/insights/order-graph-data" -Token $partnerToken -Query $query
}

# Get-GgInsightsMenuPerformanceDetails [-FromDate] [-ToDate]
#
# NOTE: unlike every other insights endpoint, this route's controller bypasses responseHandler
# and returns {success, message, data: {summary, items}, pagination} directly — confirmed against
# src/modules/insights/insights.controller.ts. There is no top-level `.result`; callers must read
# `.data`.
function Get-GgInsightsMenuPerformanceDetails {
    param([string]$FromDate, [string]$ToDate)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $query = @{}
    if ($FromDate) { $query['fromDate'] = $FromDate }
    if ($ToDate) { $query['toDate'] = $ToDate }
    return Invoke-GgHttpOrDie -Label 'insights menu performance details' -Method GET -Path "$base/v1/partner/insights/menu-performance-details" -Token $partnerToken -Query $query
}

# Get-GgInsightsCategoryRollup [-FromDate] [-ToDate]
#
# NOTE: same as menu-performance-details — returns {success, message, currency, data} directly,
# not the standard {result} envelope. Callers must read `.data`.
function Get-GgInsightsCategoryRollup {
    param([string]$FromDate, [string]$ToDate)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $query = @{}
    if ($FromDate) { $query['fromDate'] = $FromDate }
    if ($ToDate) { $query['toDate'] = $ToDate }
    return Invoke-GgHttpOrDie -Label 'insights category rollup' -Method GET -Path "$base/v1/partner/insights/category-rollup" -Token $partnerToken -Query $query
}

# Get-GgInsightsWeekly <branchId> — branchId is REQUIRED by the route's own validation
# (insightValidation.getWeeklyInsights), unlike most other insights reads.
function Get-GgInsightsWeekly {
    param([Parameter(Mandatory)][string]$BranchId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'insights weekly' -Method GET -Path "$base/v1/partner/insights/weekly" -Token $partnerToken -Query @{ branchId = $BranchId }
}

# Invoke-GgPromoteDish <itemId> — route is
# POST /v1/partner/insights/weekly/promote-dish/:itemId, NOT /v1/partner/insights/promote-dish —
# confirmed against insights.route.ts.
function Invoke-GgPromoteDish {
    param([Parameter(Mandatory)][string]$ItemId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'insights promote dish' -Method POST -Path "$base/v1/partner/insights/weekly/promote-dish/$ItemId" -Token $partnerToken
}

# Get-GgInsightsHourlyDemand <branchId> [-FromDate] [-ToDate] — branchId is REQUIRED.
function Get-GgInsightsHourlyDemand {
    param([Parameter(Mandatory)][string]$BranchId, [string]$FromDate, [string]$ToDate)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $query = @{ branchId = $BranchId }
    if ($FromDate) { $query['fromDate'] = $FromDate }
    if ($ToDate) { $query['toDate'] = $ToDate }
    return Invoke-GgHttpOrDie -Label 'insights hourly demand' -Method GET -Path "$base/v1/partner/insights/hourly-demand" -Token $partnerToken -Query $query
}
