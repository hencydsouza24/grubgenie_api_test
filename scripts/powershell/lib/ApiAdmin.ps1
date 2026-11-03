# Admin-domain verbs for 5 admin API groups — Settlement, WABA Flows, Genie, Dashboard, Partner
# Mgmt — expressed over Http.ps1 + Json.ps1, exactly like Api.ps1 is for the diner/partner
# domain. No raw Invoke-WebRequest here. Dot-sourced by Bootstrap.ps1. Mirrors
# scripts/lib/api_admin.sh function-for-function; the name mapping (bash -> PowerShell):
#
#   gg_settlement_list              -> Get-GgSettlementList
#   gg_settlement_summary           -> Get-GgSettlementSummary
#   gg_settlement_partner           -> Get-GgPartnerSettlements
#   gg_settlement_branch            -> Get-GgBranchSettlements
#   gg_settlement_calculate         -> New-GgSettlementCalculation
#   gg_settlement_calculate_batch   -> New-GgSettlementBatchCalculation
#   gg_settlement_create            -> New-GgSettlement
#   gg_settlement_create_batch      -> New-GgSettlementBatch
#   gg_settlement_get               -> Get-GgSettlement
#   gg_settlement_mark_settled      -> Set-GgSettlementMarkSettled
#   gg_waba_flow_definitions_list   -> Get-GgWabaFlowDefinitions
#   gg_waba_flow_definition_create  -> New-GgWabaFlowDefinition
#   gg_waba_flow_definition_get     -> Get-GgWabaFlowDefinition
#   gg_waba_flow_definition_update  -> Update-GgWabaFlowDefinition
#   gg_waba_flow_definition_release -> Invoke-GgWabaFlowDefinitionRelease
#   gg_waba_flow_deployments_list   -> Get-GgWabaFlowDeployments
#   gg_waba_flow_deployment_retry   -> Invoke-GgWabaFlowDeploymentRetry
#   gg_waba_flow_deployment_deprecate -> Invoke-GgWabaFlowDeploymentDeprecate
#   gg_genie_fleet                  -> Get-GgGenieFleet
#   gg_genie_sessions                -> Get-GgGenieSessions
#   gg_genie_thread_get             -> Get-GgGenieThread
#   gg_genie_thread_activity        -> Get-GgGenieThreadActivity
#   gg_genie_thread_evict           -> Remove-GgGenieThread
#   gg_genie_thread_signal          -> Send-GgGenieThreadSignal
#   gg_genie_thread_chat            -> Send-GgGenieChatMessage
#   gg_genie_thread_end             -> Stop-GgGenieThread
#   gg_genie_spawn                  -> New-GgGenieSession
#   gg_dashboard_summary            -> Get-GgDashboardSummary
#   gg_dashboard_timeseries         -> Get-GgDashboardTimeseries
#   gg_dashboard_top                -> Get-GgDashboardTop
#   gg_partner_list                  -> Get-GgAdminPartners
#   gg_partner_get                   -> Get-GgAdminPartner
#   gg_partner_patch                  -> Update-GgAdminPartner
#   gg_partner_agent_contexts         -> Get-GgAllBranchAgentContexts
#   gg_partner_branch_contexts        -> Get-GgPartnerBranchAgentContexts
#   gg_partner_branch_context_get     -> Get-GgBranchAgentContext
#   gg_partner_branch_context_put     -> Set-GgBranchAgentContext

if (Get-Variable -Name _GgApiAdminLoaded -Scope Script -ErrorAction SilentlyContinue) { return }
$Script:_GgApiAdminLoaded = $true

# --- Admin Settlement (/v1/admin/settlement) ---

function Get-GgSettlementList {
    param([hashtable]$Query)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'settlement list' -Method GET -Path "$base/v1/admin/settlement" -Token $adminToken -Query $Query
}

function Get-GgSettlementSummary {
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'settlement summary' -Method GET -Path "$base/v1/admin/settlement/summary" -Token $adminToken
}

function Get-GgPartnerSettlements {
    param([Parameter(Mandatory)][string]$PartnerId, [hashtable]$Query)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'partner settlements' -Method GET -Path "$base/v1/admin/settlement/partners/$PartnerId" -Token $adminToken -Query $Query
}

function Get-GgBranchSettlements {
    param([Parameter(Mandatory)][string]$BranchId, [hashtable]$Query)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'branch settlements' -Method GET -Path "$base/v1/admin/settlement/branches/$BranchId" -Token $adminToken -Query $Query
}

# New-GgSettlementCalculation <partnerId> <periodFrom> <periodTo> [branchId] — preview only.
function New-GgSettlementCalculation {
    param(
        [Parameter(Mandatory)][string]$PartnerId,
        [Parameter(Mandatory)][string]$PeriodFrom,
        [Parameter(Mandatory)][string]$PeriodTo,
        [string]$BranchId
    )
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    $fields = @{ partnerId = $PartnerId; periodFrom = $PeriodFrom; periodTo = $PeriodTo }
    if ($BranchId) { $fields['branchId'] = $BranchId }
    $body = $fields | ConvertTo-Json -Compress -Depth 5
    return Invoke-GgHttpOrDie -Label 'settlement calculate' -Method POST -Path "$base/v1/admin/settlement/calculate" -Token $adminToken -JsonBody $body
}

# ConvertTo-GgSettlementTargets <partnerId[:branchId]> [...] → an array of {partnerId, branchId?}
# hashtables for the batch calculate/create endpoints' required `targets` field.
function ConvertTo-GgSettlementTargets {
    param([string[]]$Tokens)
    $targets = foreach ($token in $Tokens) {
        if ($token -match '^([^:]+):(.+)$') {
            @{ partnerId = $Matches[1]; branchId = $Matches[2] }
        }
        else {
            @{ partnerId = $token }
        }
    }
    return @($targets)
}

# New-GgSettlementBatchCalculation <periodFrom> <periodTo> <partnerId[:branchId]> [...]
function New-GgSettlementBatchCalculation {
    param(
        [Parameter(Mandatory)][string]$PeriodFrom,
        [Parameter(Mandatory)][string]$PeriodTo,
        [Parameter(Mandatory)][string[]]$Targets
    )
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    $body = @{ periodFrom = $PeriodFrom; periodTo = $PeriodTo; targets = (ConvertTo-GgSettlementTargets -Tokens $Targets) } | ConvertTo-Json -Compress -Depth 5
    return Invoke-GgHttpOrDie -Label 'settlement batch calculate' -Method POST -Path "$base/v1/admin/settlement/batch/calculate" -Token $adminToken -JsonBody $body
}

# New-GgSettlement <partnerId> <periodFrom> <periodTo> [branchId] [notes] — writes a real
# settlement record (unlike New-GgSettlementCalculation).
function New-GgSettlement {
    param(
        [Parameter(Mandatory)][string]$PartnerId,
        [Parameter(Mandatory)][string]$PeriodFrom,
        [Parameter(Mandatory)][string]$PeriodTo,
        [string]$BranchId,
        [string]$Notes
    )
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    $fields = @{ partnerId = $PartnerId; periodFrom = $PeriodFrom; periodTo = $PeriodTo }
    if ($BranchId) { $fields['branchId'] = $BranchId }
    if ($Notes) { $fields['notes'] = $Notes }
    $body = $fields | ConvertTo-Json -Compress -Depth 5
    return Invoke-GgHttpOrDie -Label 'settlement create' -Method POST -Path "$base/v1/admin/settlement" -Token $adminToken -JsonBody $body
}

# New-GgSettlementBatch <periodFrom> <periodTo> <partnerId[:branchId]> [...]
function New-GgSettlementBatch {
    param(
        [Parameter(Mandatory)][string]$PeriodFrom,
        [Parameter(Mandatory)][string]$PeriodTo,
        [Parameter(Mandatory)][string[]]$Targets
    )
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    $body = @{ periodFrom = $PeriodFrom; periodTo = $PeriodTo; targets = (ConvertTo-GgSettlementTargets -Tokens $Targets) } | ConvertTo-Json -Compress -Depth 5
    return Invoke-GgHttpOrDie -Label 'settlement batch create' -Method POST -Path "$base/v1/admin/settlement/batch" -Token $adminToken -JsonBody $body
}

function Get-GgSettlement {
    param([Parameter(Mandatory)][string]$SettlementId)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'settlement get' -Method GET -Path "$base/v1/admin/settlement/$SettlementId" -Token $adminToken
}

# Set-GgSettlementMarkSettled <settlementId> [notes]
function Set-GgSettlementMarkSettled {
    param([Parameter(Mandatory)][string]$SettlementId, [string]$Notes)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    $body = New-GgJsonObj @{ notes = $Notes }
    return Invoke-GgHttpOrDie -Label 'settlement mark-settled' -Method PUT -Path "$base/v1/admin/settlement/$SettlementId/mark-settled" -Token $adminToken -JsonBody $body
}

# --- Admin WABA Flows (/v1/admin/waba/flows) ---
#
# `manageFlows` is deliberately excluded from the wabaMiddleware API-key role in
# src/config/roles.ts (only super-admin has it) — unlike every sibling admin/waba/* route, these
# calls use Get-GgCachedAdminToken (admin bearer), NOT an X-Api-Key header, even though the route
# itself accepts either via authJwtOrApiKey.

function Get-GgWabaFlowDefinitions {
    param([hashtable]$Query)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'waba flow definitions list' -Method GET -Path "$base/v1/admin/waba/flows/definitions" -Token $adminToken -Query $Query
}

# New-GgWabaFlowDefinition <key> <name> <categories-csv> <flowJson> [autoProvision]
# categories-csv: comma-separated values from WABA_FLOW_CATEGORIES (e.g. "SIGN_UP,CONTACT_US").
function New-GgWabaFlowDefinition {
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$CategoriesCsv,
        [Parameter(Mandatory)][string]$FlowJson,
        [string]$AutoProvision
    )
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    $fields = @{ key = $Key; name = $Name; categories = @($CategoriesCsv -split ','); flowJson = $FlowJson }
    if ($AutoProvision) { $fields['autoProvision'] = [bool]::Parse($AutoProvision) }
    $body = $fields | ConvertTo-Json -Compress -Depth 5
    return Invoke-GgHttpOrDie -Label 'waba flow definition create' -Method POST -Path "$base/v1/admin/waba/flows/definitions" -Token $adminToken -JsonBody $body
}

function Get-GgWabaFlowDefinition {
    param([Parameter(Mandatory)][string]$DefinitionId)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'waba flow definition get' -Method GET -Path "$base/v1/admin/waba/flows/definitions/$DefinitionId" -Token $adminToken
}

# Update-GgWabaFlowDefinition <definitionId> [name] [categories-csv] [flowJson] [autoProvision]
# — leave any optional field empty/omitted to not update it.
function Update-GgWabaFlowDefinition {
    param(
        [Parameter(Mandatory)][string]$DefinitionId,
        [string]$Name,
        [string]$CategoriesCsv,
        [string]$FlowJson,
        [string]$AutoProvision
    )
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    $fields = @{}
    if ($Name) { $fields['name'] = $Name }
    if ($CategoriesCsv) { $fields['categories'] = @($CategoriesCsv -split ',') }
    if ($FlowJson) { $fields['flowJson'] = $FlowJson }
    if ($AutoProvision) { $fields['autoProvision'] = [bool]::Parse($AutoProvision) }
    $body = $fields | ConvertTo-Json -Compress -Depth 5
    return Invoke-GgHttpOrDie -Label 'waba flow definition update' -Method PATCH -Path "$base/v1/admin/waba/flows/definitions/$DefinitionId" -Token $adminToken -JsonBody $body
}

function Invoke-GgWabaFlowDefinitionRelease {
    param([Parameter(Mandatory)][string]$DefinitionId)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'waba flow definition release' -Method POST -Path "$base/v1/admin/waba/flows/definitions/$DefinitionId/release" -Token $adminToken
}

function Get-GgWabaFlowDeployments {
    param([hashtable]$Query)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'waba flow deployments list' -Method GET -Path "$base/v1/admin/waba/flows/deployments" -Token $adminToken -Query $Query
}

function Invoke-GgWabaFlowDeploymentRetry {
    param([Parameter(Mandatory)][string]$DeploymentId)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'waba flow deployment retry' -Method POST -Path "$base/v1/admin/waba/flows/deployments/$DeploymentId/retry" -Token $adminToken
}

function Invoke-GgWabaFlowDeploymentDeprecate {
    param([Parameter(Mandatory)][string]$DeploymentId)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'waba flow deployment deprecate' -Method POST -Path "$base/v1/admin/waba/flows/deployments/$DeploymentId/deprecate" -Token $adminToken
}

# --- Admin Genie (/v1/admin/genie) ---
#
# threadId is a composite "diner-agent:<cartId>:<dinerId>" (see buildThreadId in
# src/modules/genieV2/genie.helpers.ts) — build it yourself from a spawned session's cartId and
# dinerId before calling any thread-scoped function below. Colons in a URL path segment pass
# through Invoke-WebRequest unencoded without trouble, so no manual encoding is done here.

function Get-GgGenieFleet {
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'genie fleet' -Method GET -Path "$base/v1/admin/genie/fleet" -Token $adminToken
}

# Get-GgGenieSessions [-Page] [-Limit] [-FromTimestamp] [-ToTimestamp] — omit a param to skip it.
function Get-GgGenieSessions {
    param([string]$Page, [string]$Limit, [string]$FromTimestamp, [string]$ToTimestamp)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    $query = @{}
    if ($Page) { $query['page'] = $Page }
    if ($Limit) { $query['limit'] = $Limit }
    if ($FromTimestamp) { $query['fromTimestamp'] = $FromTimestamp }
    if ($ToTimestamp) { $query['toTimestamp'] = $ToTimestamp }
    return Invoke-GgHttpOrDie -Label 'genie sessions' -Method GET -Path "$base/v1/admin/genie/sessions" -Token $adminToken -Query $query
}

function Get-GgGenieThread {
    param([Parameter(Mandatory)][string]$ThreadId)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'genie thread get' -Method GET -Path "$base/v1/admin/genie/threads/$ThreadId" -Token $adminToken
}

# Get-GgGenieThreadActivity <threadId> [limit]
function Get-GgGenieThreadActivity {
    param([Parameter(Mandatory)][string]$ThreadId, [string]$Limit)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    $query = @{}
    if ($Limit) { $query['limit'] = $Limit }
    return Invoke-GgHttpOrDie -Label 'genie thread activity' -Method GET -Path "$base/v1/admin/genie/threads/$ThreadId/activity" -Token $adminToken -Query $query
}

function Remove-GgGenieThread {
    param([Parameter(Mandatory)][string]$ThreadId)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'genie thread evict' -Method DELETE -Path "$base/v1/admin/genie/threads/$ThreadId" -Token $adminToken
}

# Send-GgGenieThreadSignal <threadId> <type> [payloadJson] — validation only requires `signal` to
# be an object; {type, payload} mirrors the ParsedBehaviorSignal shape genie.helpers expects.
function Send-GgGenieThreadSignal {
    param([Parameter(Mandatory)][string]$ThreadId, [Parameter(Mandatory)][string]$SignalType, [string]$PayloadJson = '{}')
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    $body = @{ signal = @{ type = $SignalType; payload = ($PayloadJson | ConvertFrom-Json) } } | ConvertTo-Json -Compress -Depth 5
    return Invoke-GgHttpOrDie -Label 'genie thread signal' -Method POST -Path "$base/v1/admin/genie/threads/$ThreadId/signal" -Token $adminToken -JsonBody $body
}

function Send-GgGenieChatMessage {
    param([Parameter(Mandatory)][string]$ThreadId, [Parameter(Mandatory)][string]$Message)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    $body = New-GgJsonObj @{ message = $Message }
    return Invoke-GgHttpOrDie -Label 'genie thread chat' -Method POST -Path "$base/v1/admin/genie/threads/$ThreadId/chat" -Token $adminToken -JsonBody $body
}

function Stop-GgGenieThread {
    param([Parameter(Mandatory)][string]$ThreadId)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'genie thread end' -Method POST -Path "$base/v1/admin/genie/threads/$ThreadId/end" -Token $adminToken
}

# New-GgGenieSession <dinerId> <cartId> <branchId> <accountId> <partnerId> <tableId> — all six
# fields are required by validation, even though some look optional at a glance.
function New-GgGenieSession {
    param(
        [Parameter(Mandatory)][string]$DinerId,
        [Parameter(Mandatory)][string]$CartId,
        [Parameter(Mandatory)][string]$BranchId,
        [Parameter(Mandatory)][string]$AccountId,
        [Parameter(Mandatory)][string]$PartnerId,
        [Parameter(Mandatory)][string]$TableId
    )
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    $body = @{ dinerId = $DinerId; cartId = $CartId; branchId = $BranchId; accountId = $AccountId; partnerId = $PartnerId; tableId = $TableId } | ConvertTo-Json -Compress -Depth 5
    return Invoke-GgHttpOrDie -Label 'genie spawn' -Method POST -Path "$base/v1/admin/genie/spawn" -Token $adminToken -JsonBody $body
}

# --- Admin Dashboard (/v1/admin/dashboard) ---

function Get-GgDashboardSummary {
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'dashboard summary' -Method GET -Path "$base/v1/admin/dashboard/summary" -Token $adminToken
}

# Get-GgDashboardTimeseries <metric> <interval> [from] [to]
# metric: orders|signups|partners|revenue   interval: day|week
function Get-GgDashboardTimeseries {
    param(
        [Parameter(Mandatory)][string]$Metric,
        [Parameter(Mandatory)][string]$Interval,
        [string]$From,
        [string]$To
    )
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    $query = @{ metric = $Metric; interval = $Interval }
    if ($From) { $query['from'] = $From }
    if ($To) { $query['to'] = $To }
    return Invoke-GgHttpOrDie -Label 'dashboard timeseries' -Method GET -Path "$base/v1/admin/dashboard/timeseries" -Token $adminToken -Query $query
}

# Get-GgDashboardTop <metric> [limit]
# metric: partners-by-orders|diners-by-orders|dishes|cuisines|partners-by-revenue
function Get-GgDashboardTop {
    param([Parameter(Mandatory)][string]$Metric, [string]$Limit)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    $query = @{ metric = $Metric }
    if ($Limit) { $query['limit'] = $Limit }
    return Invoke-GgHttpOrDie -Label 'dashboard top' -Method GET -Path "$base/v1/admin/dashboard/top" -Token $adminToken -Query $query
}

# --- Admin Partner Mgmt (/v1/admin/partner) ---

function Get-GgAdminPartners {
    param([hashtable]$Query)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'partner list' -Method GET -Path "$base/v1/admin/partner" -Token $adminToken -Query $Query
}

function Get-GgAdminPartner {
    param([Parameter(Mandatory)][string]$AccountId)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'partner get' -Method GET -Path "$base/v1/admin/partner/$AccountId" -Token $adminToken
}

# Update-GgAdminPartner <accountId> <fields hashtable> — free-form $set; the route has no body
# validation, so any field name is accepted as-is.
function Update-GgAdminPartner {
    param([Parameter(Mandatory)][string]$AccountId, [Parameter(Mandatory)][hashtable]$Fields)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    $body = New-GgJsonObj $Fields
    return Invoke-GgHttpOrDie -Label 'partner patch' -Method PATCH -Path "$base/v1/admin/partner/$AccountId" -Token $adminToken -JsonBody $body
}

function Get-GgAllBranchAgentContexts {
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'partner agent contexts' -Method GET -Path "$base/v1/admin/partner/agent-contexts" -Token $adminToken
}

function Get-GgPartnerBranchAgentContexts {
    param([Parameter(Mandatory)][string]$AccountId)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'partner branch contexts' -Method GET -Path "$base/v1/admin/partner/$AccountId/branches/agent-context" -Token $adminToken
}

function Get-GgBranchAgentContext {
    param([Parameter(Mandatory)][string]$AccountId, [Parameter(Mandatory)][string]$BranchId)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'partner branch context get' -Method GET -Path "$base/v1/admin/partner/$AccountId/branches/$BranchId/agent-context" -Token $adminToken
}

# Set-GgBranchAgentContext <accountId> <branchId> <context>
function Set-GgBranchAgentContext {
    param([Parameter(Mandatory)][string]$AccountId, [Parameter(Mandatory)][string]$BranchId, [Parameter(Mandatory)][string]$Context)
    $base = Get-GgSessionValue -Key 'base'
    $adminToken = Get-GgCachedAdminToken
    $body = New-GgJsonObj @{ context = $Context }
    return Invoke-GgHttpOrDie -Label 'partner branch context put' -Method PUT -Path "$base/v1/admin/partner/$AccountId/branches/$BranchId/agent-context" -Token $adminToken -JsonBody $body
}
