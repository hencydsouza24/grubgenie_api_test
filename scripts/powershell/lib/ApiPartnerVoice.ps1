# Partner Voice domain verbs — PowerShell twin of ../../lib/api_partner_voice.sh. HeyKoala
# voice-agent connection (saved config under /v1/partner/voice/connection) + call history/sync
# (/v1/partner/voice/calls, routed from src/modules/voice/calls.*). Expressed over Http.ps1 +
# Json.ps1, exactly like Api.ps1. Not yet dot-sourced by Bootstrap.ps1 (wired centrally later to
# avoid collisions with sibling lib files being added in parallel) — scripts that need these
# functions dot-source this file directly, after Bootstrap.ps1.
#
# Bash -> PowerShell name mapping (mirrors Api.ps1's own header convention):
#   gg_voice_connection_options -> Get-GgVoiceConnectionOptions
#   gg_voice_validate_key       -> Test-GgVoiceApiKey
#   gg_voice_connection_get     -> Get-GgVoiceConnection
#   gg_voice_connection_save    -> Set-GgVoiceConnection
#   gg_voice_rotate_tool_key    -> Update-GgVoiceToolKey
#   gg_voice_connection_test    -> Test-GgVoiceConnection
#   gg_voice_go_live            -> Enable-GgVoiceLive
#   gg_voice_connection_delete  -> Remove-GgVoiceConnection
#   gg_voice_calls_list         -> Get-GgVoiceCalls
#   gg_voice_calls_stats        -> Get-GgVoiceCallStats
#   gg_voice_calls_sync         -> Start-GgVoiceCallsSync
#   gg_voice_calls_linked       -> Get-GgVoiceLinkedCall
#   gg_voice_calls_get          -> Get-GgVoiceCall

if (Get-Variable -Name _GgApiPartnerVoiceLoaded -Scope Script -ErrorAction SilentlyContinue) { return }
$Script:_GgApiPartnerVoiceLoaded = $true

# --- Connection group (auth: manageReservationSettings) ---

function Get-GgVoiceConnectionOptions {
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'voice connection options' -Method GET -Path "$base/v1/partner/voice/connection/options" -Token $partnerToken
}

# Test-GgVoiceApiKey <ApiKey> — field is `apiKey` (confirmed in voice.validation.ts).
function Test-GgVoiceApiKey {
    param([Parameter(Mandatory)][string]$ApiKey)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $body = New-GgJsonObj @{ apiKey = $ApiKey }
    return Invoke-GgHttpOrDie -Label 'voice validate key' -Method POST -Path "$base/v1/partner/voice/connection/validate-key" -Token $partnerToken -JsonBody $body
}

function Get-GgVoiceConnection {
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'voice connection get' -Method GET -Path "$base/v1/partner/voice/connection" -Token $partnerToken
}

# Set-GgVoiceConnection <AgentId> <PhoneNumberId> <CallFlowId> [-ApiKey K] — apiKey is optional on
# PUT (only required on Test-GgVoiceApiKey); the other three are required.
function Set-GgVoiceConnection {
    param(
        [Parameter(Mandatory)][string]$AgentId,
        [Parameter(Mandatory)][string]$PhoneNumberId,
        [Parameter(Mandatory)][string]$CallFlowId,
        [string]$ApiKey
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $fields = @{ agentId = $AgentId; phoneNumberId = $PhoneNumberId; callFlowId = $CallFlowId }
    if ($ApiKey) { $fields['apiKey'] = $ApiKey }
    $body = $fields | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'voice connection save' -Method PUT -Path "$base/v1/partner/voice/connection" -Token $partnerToken -JsonBody $body
}

# Update-GgVoiceToolKey — route is `/connection/rotate-tool-key`, not `/connection/rotate-key`.
function Update-GgVoiceToolKey {
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'voice rotate tool key' -Method POST -Path "$base/v1/partner/voice/connection/rotate-tool-key" -Token $partnerToken
}

# Test-GgVoiceConnection <BranchId> <Date YYYY-MM-DD> <PartySize>
function Test-GgVoiceConnection {
    param(
        [Parameter(Mandatory)][string]$BranchId,
        [Parameter(Mandatory)][string]$Date,
        [Parameter(Mandatory)][int]$PartySize
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $body = @{ branchId = $BranchId; date = $Date; partySize = $PartySize } | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'voice connection test' -Method POST -Path "$base/v1/partner/voice/connection/test" -Token $partnerToken -JsonBody $body
}

function Enable-GgVoiceLive {
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'voice go live' -Method POST -Path "$base/v1/partner/voice/connection/go-live" -Token $partnerToken
}

# Remove-GgVoiceConnection → the response message (controller returns `result: {}`, so the
# message is the only useful signal here — same shape as Set-GgTableStatus).
function Remove-GgVoiceConnection {
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $resp = Invoke-GgHttpOrDie -Label 'voice connection delete' -Method DELETE -Path "$base/v1/partner/voice/connection" -Token $partnerToken
    return Get-GgJsonMessage -Json $resp
}

# --- Calls group (auth: getReservations for reads, manageReservationSettings for sync) ---

# Get-GgVoiceCalls [-Query @{...}] — optional query: page, limit, direction, from, to, branchId,
# outcome, q (all optional per calls.validation.ts).
function Get-GgVoiceCalls {
    param([hashtable]$Query)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'voice calls list' -Method GET -Path "$base/v1/partner/voice/calls" -Token $partnerToken -Query $Query
}

# Get-GgVoiceCallStats [-Query @{...}] — same query shape as Get-GgVoiceCalls (confirmed: both
# routes share callsValidation.listCalls, there is no separate stats-only schema).
function Get-GgVoiceCallStats {
    param([hashtable]$Query)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'voice calls stats' -Method GET -Path "$base/v1/partner/voice/calls/stats" -Token $partnerToken -Query $Query
}

function Start-GgVoiceCallsSync {
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'voice calls sync' -Method POST -Path "$base/v1/partner/voice/calls/sync" -Token $partnerToken
}

# Get-GgVoiceLinkedCall <LinkKey> <LinkId> — LinkKey is exactly `reservationId` or `inquiryId`
# (the route validates them as mutually exclusive — `.xor('reservationId', 'inquiryId')`). Mirrors
# Api.ps1's New-GgOrder <CartId> <LineKey> <LineId> pattern: the type is passed explicitly as data
# rather than guessed from the id's shape (both are plain ObjectId strings).
function Get-GgVoiceLinkedCall {
    param(
        [Parameter(Mandatory)][ValidateSet('reservationId', 'inquiryId')][string]$LinkKey,
        [Parameter(Mandatory)][string]$LinkId
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $query = @{ $LinkKey = $LinkId }
    return Invoke-GgHttpOrDie -Label 'voice calls linked' -Method GET -Path "$base/v1/partner/voice/calls/linked" -Token $partnerToken -Query $query
}

function Get-GgVoiceCall {
    param([Parameter(Mandatory)][string]$CallId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'voice call get' -Method GET -Path "$base/v1/partner/voice/calls/$CallId" -Token $partnerToken
}
