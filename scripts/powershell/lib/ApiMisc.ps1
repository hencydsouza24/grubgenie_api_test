# Non-admin-bearer verbs for the long tail of small ops/diagnostic endpoints: the agents module
# (API key / no-auth), debug health/connections, the WhatsApp click redirect, and the voice tool
# webhook. Expressed over Http.ps1 + Json.ps1. Dot-sourced by Bootstrap.ps1. Mirrors
# scripts/lib/api_misc.sh function-for-function; the name mapping (bash -> PowerShell) is kept
# here, exactly like Api.ps1's own header:
#
#   gg_agents_topic            -> Get-GgAgentsTopic
#   gg_agents_partner_info     -> Get-GgAgentsPartnerInfo
#   gg_debug_health            -> Get-GgDebugHealth
#   gg_debug_connections       -> Get-GgDebugConnections
#   gg_redirect                -> Invoke-GgRedirect
#   gg_voice_tool_webhook      -> Invoke-GgVoiceToolWebhook
#
# Most of these endpoints need no GrubGenie diner/partner session at all (confirmed per-route
# below), so — unlike Api.ps1/ApiAdminMisc.ps1 — most functions here resolve the base URL
# directly via `Resolve-GgBase` instead of `Get-GgSessionValue -Key base`, the same way
# fetch_menu.ps1's `branches` command avoids forcing an auth flow for a route that doesn't need
# one. The one exception (Get-GgDebugConnections) needs an admin bearer token, which still goes
# through the normal session machinery.

if (Get-Variable -Name _GgApiMiscLoaded -Scope Script -ErrorAction SilentlyContinue) { return }
$Script:_GgApiMiscLoaded = $true

# --- Agents module ---

# Get-GgAgentsTopic <topicKey> <partnerId> [-BranchId b] — GET /v1/agents/knowledge-base/topics/:topicKey.
# Auth is `authApiKey()` + `requireApiKeyPartnerAccess`, i.e. a literal `X-Api-Key` header (NOT
# Authorization: Bearer) — confirmed against src/routes/v1/agents/knowledgeBase.route.ts and
# src/modules/apiKey/apiKey.strategy.ts (passport-headerapikey, header 'X-Api-Key', no prefix).
# Reuses $env:GG_WABA_MIDDLEWARE_API_KEY — same service-account key as the admin WABA resolve
# routes, not a second credential.
function Get-GgAgentsTopic {
    param([Parameter(Mandatory)][string]$TopicKey, [Parameter(Mandatory)][string]$PartnerId, [string]$BranchId)
    Import-GgCredentials
    if (-not $env:GG_WABA_MIDDLEWARE_API_KEY) {
        Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'GG_WABA_MIDDLEWARE_API_KEY not set — see scripts/config/credentials.example.env'
    }
    $base = Resolve-GgBase
    $query = @{ partnerId = $PartnerId }
    if ($BranchId) { $query['branchId'] = $BranchId }
    return Invoke-GgHttpOrDie -Label 'agents topic' -Method GET -Path "$base/v1/agents/knowledge-base/topics/$TopicKey" -Query $query -Headers @{ 'X-Api-Key' = $env:GG_WABA_MIDDLEWARE_API_KEY }
}

# Get-GgAgentsPartnerInfo <partnerId> [-BranchId b] — GET /v1/agents/partner/:partnerId.
# NO auth middleware at all — confirmed against src/routes/v1/agents/partner.route.ts (an
# unusual but real finding, not a mistake).
function Get-GgAgentsPartnerInfo {
    param([Parameter(Mandatory)][string]$PartnerId, [string]$BranchId)
    $base = Resolve-GgBase
    $query = @{}
    if ($BranchId) { $query['branchId'] = $BranchId }
    return Invoke-GgHttpOrDie -Label 'agents partner-info' -Method GET -Path "$base/v1/agents/partner/$PartnerId" -Query $query
}

# --- Debug ---

# Get-GgDebugHealth — GET /v1/health, NOT /v1/debug/health. The audit this task was scoped from
# assumed a GET /v1/debug/health with zero auth; the real debug.route.ts has no /health endpoint
# at all (its routes are /memory, /gc, /heap-snapshot, /heap-stats, /active-handles,
# /connections, ALL behind `router.use(auth(permissions.sysInfo.getSysInfo))`). The actual
# zero-auth health check is a SEPARATE top-level route mounted at /v1/health
# (src/routes/v1/health.route.ts, src/routes/v1/index.ts) — that's what this function calls.
function Get-GgDebugHealth {
    $base = Resolve-GgBase
    return Invoke-GgHttpOrDie -Label 'debug health' -Method GET -Path "$base/v1/health"
}

function Get-GgDebugConnections {
    $base = Get-GgSessionValue -Key 'base'
    $token = Get-GgCachedAdminToken
    return Invoke-GgHttpOrDie -Label 'debug connections' -Method GET -Path "$base/v1/debug/connections" -Token $token
}

# --- Redirect ---

# Invoke-GgRedirect <buttonIndex> <ref> — GET /v1/redirect/:buttonIndex/:ref. Public, no auth. A
# WhatsApp click-tracking redirect that 302s to the real destination.
#
# CAVEAT: Invoke-GgHttp (lib/Http.ps1) uses Invoke-WebRequest, which — like curl's `-L` on the
# bash side — FOLLOWS redirects by default; there is no way to observe the redirect route's own
# 3xx through the existing transport. $Script:GgHttpStatus ends up being the FINAL destination's
# status after following every hop, not the redirect's. Per this task's own instruction not to
# rearchitect Http.ps1 for this one case, this is called with -Expect 'any' and the
# (post-redirect) status is surfaced to the caller to interpret — it is NOT proof the redirect
# route itself returned a 3xx.
function Invoke-GgRedirect {
    param([Parameter(Mandatory)][string]$ButtonIndex, [Parameter(Mandatory)][string]$Ref)
    $base = Resolve-GgBase
    Invoke-GgHttp -Method GET -Path "$base/v1/redirect/$ButtonIndex/$Ref" -Expect 'any' | Out-Null
    return [PSCustomObject]@{
        status = $Script:GgHttpStatus
        note   = 'status is POST-redirect (Invoke-WebRequest follows it); the route''s own 3xx is not observable through Invoke-GgHttp — see ApiMisc.ps1'
    } | ConvertTo-Json -Compress
}

# --- Voice tool webhook ---

# Invoke-GgVoiceToolWebhook <tool> [-Params @{k=v}] — GET /v1/voice/tools/:toolKey/:tool.
#
# :toolKey is NOT taken as a parameter, deliberately: it's a real per-partner provisioned secret
# (gatewayController.runTool hashes it and compares against a per-partner stored hash in the DB
# — this skill can't generate a valid one), not a public test fixture like the other path params
# in this file. So it's sourced from $env:GG_VOICE_TOOL_KEY in credentials.env, the same way
# Set-GgPosConfig takes zero parameters for GG_PETPOOJA_APP_SECRET — never passed on the command
# line. -Params becomes query params — e.g. for `-Tool availability`:
# @{ partnerId = ...; branchId = ...; date = ...; partySize = ... }
function Invoke-GgVoiceToolWebhook {
    param([Parameter(Mandatory)][string]$Tool, [hashtable]$Params)
    Import-GgCredentials
    if (-not $env:GG_VOICE_TOOL_KEY) {
        Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'GG_VOICE_TOOL_KEY not set — see scripts/config/credentials.example.env'
    }
    $base = Resolve-GgBase
    return Invoke-GgHttpOrDie -Label 'voice webhook' -Method GET -Path "$base/v1/voice/tools/$env:GG_VOICE_TOOL_KEY/$Tool" -Query $Params
}
