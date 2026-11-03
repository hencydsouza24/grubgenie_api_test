# Staff-assisted ordering, reservation widget + public reservation, front-desk report, WhatsApp
# agent settings/audience segments, order-history active-by-table, and diner genie extensions.
# Mirrors scripts/lib/api_partner_misc.sh function-for-function; the name mapping (bash -> PS):
#
#   gg_staff_cart_create                  -> New-GgStaffCart
#   gg_staff_order_create                 -> New-GgStaffOrder
#   gg_staff_order_update                  -> Update-GgStaffOrder
#   gg_staff_order_place                    -> Submit-GgStaffOrder
#   gg_reservation_widget_embed             -> Get-GgReservationWidgetEmbed
#   gg_reservation_public_get               -> Get-GgPublicReservation
#   gg_reservation_public_review            -> Get-GgPublicReservationReview
#   gg_reservation_public_availability      -> Get-GgPublicReservationAvailability
#   gg_reservation_public_modify            -> Update-GgPublicReservation
#   gg_reservation_public_cancel            -> Cancel-GgPublicReservation
#   gg_front_desk_report                    -> Get-GgFrontDeskReport
#   gg_front_desk_report_export             -> Export-GgFrontDeskReport
#   gg_whatsapp_agent_settings_get          -> Get-GgWhatsappAgentSettings
#   gg_whatsapp_agent_settings_update       -> Set-GgWhatsappAgentSettings
#   gg_whatsapp_audience_segments           -> Get-GgWhatsappAudienceSegments
#   gg_order_active_by_table                -> Get-GgActiveOrderByTable
#   gg_combo_list                           -> Get-GgComboList
#   gg_combo_get                            -> Get-GgDinerCombo
#   gg_diner_order_detail                   -> Get-GgDinerOrderDetail
#   gg_diner_link_identity                  -> Confirm-GgLinkIdentity
#
# Not yet dot-sourced from Bootstrap.ps1 (central integration pass handles that) — scripts using
# this file dot-source it directly, after Bootstrap.ps1:
#   . "$PSScriptRoot/lib/Bootstrap.ps1"
#   . "$PSScriptRoot/lib/ApiPartnerMisc.ps1"

if (Get-Variable -Name _GgApiPartnerMiscLoaded -Scope Script -ErrorAction SilentlyContinue) { return }
$Script:_GgApiPartnerMiscLoaded = $true

# --- Staff Order (partner bearer; waiter/captain acting on behalf of a diner/table) ---
#
# Confirmed from src/routes/v1/partner/order.route.ts + staffOrder.controller.ts: this is its OWN
# route file (mounted at /v1/partner/order), not a reuse of the diner-facing /v1/genie/cart +
# /v1/genie/order routes under a different token.

# New-GgStaffCart <TableId> → returns cartId. POST .../table/:tableId/cart takes no body; the
# response IS the raw cart doc (unlike the diner-facing New-GgCart, which gets a custom
# {cartId,...} wrapper) — so the id is `.result._id`, not `.result.cartId`.
function New-GgStaffCart {
    param([Parameter(Mandatory)][string]$TableId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $resp = Invoke-GgHttpOrDie -Label 'staff cart create' -Method POST -Path "$base/v1/partner/order/table/$TableId/cart" -Token $partnerToken
    return Get-GgJsonField -Json $resp -Path '.result._id' -Label 'cartId'
}

# New-GgStaffOrder <CartId> <LineKey> <LineId> [Qty] — lineKey is "itemId" or "comboId". Returns
# the orderId, read off `.result.currentActiveOrder` (same field the diner-facing New-GgOrder reads).
function New-GgStaffOrder {
    param(
        [Parameter(Mandatory)][string]$CartId,
        [Parameter(Mandatory)][ValidateSet('itemId', 'comboId')][string]$LineKey,
        [Parameter(Mandatory)][string]$LineId,
        [int]$Qty = 1
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $line = @{ quantity = $Qty }
    $line[$LineKey] = $LineId
    $body = @{ items = @($line) } | ConvertTo-Json -Compress -Depth 5

    $resp = Invoke-GgHttpOrDie -Label 'staff order create' -Method POST -Path "$base/v1/partner/order/cart/$CartId/items" -Token $partnerToken -JsonBody $body
    return Get-GgJsonField -Json $resp -Path '.result.currentActiveOrder' -Label 'orderId'
}

# Update-GgStaffOrder <OrderId> <CartId> <LineKey> <LineId> [Qty] — merges one more item onto an
# existing order. Returns the raw cart-with-orders response.
function Update-GgStaffOrder {
    param(
        [Parameter(Mandatory)][string]$OrderId,
        [Parameter(Mandatory)][string]$CartId,
        [Parameter(Mandatory)][ValidateSet('itemId', 'comboId')][string]$LineKey,
        [Parameter(Mandatory)][string]$LineId,
        [int]$Qty = 1
    )
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $line = @{ quantity = $Qty }
    $line[$LineKey] = $LineId
    $body = @{ items = @($line) } | ConvertTo-Json -Compress -Depth 5

    return Invoke-GgHttpOrDie -Label 'staff order update' -Method PUT -Path "$base/v1/partner/order/order/$OrderId/items" `
        -Token $partnerToken -JsonBody $body -Query @{ cartId = $CartId }
}

# Submit-GgStaffOrder <OrderId> <CartId> → returns @{ Message; Status }. Same extraction as the
# diner-facing Submit-GgOrder: Status comes from `.result.orders[]`, never parsed out of Message.
function Submit-GgStaffOrder {
    param([Parameter(Mandatory)][string]$OrderId, [Parameter(Mandatory)][string]$CartId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $resp = Invoke-GgHttpOrDie -Label 'staff place order' -Method PUT -Path "$base/v1/partner/order/order/$OrderId/place" `
        -Token $partnerToken -Query @{ cartId = $CartId }

    $message = Get-GgJsonMessage -Json $resp
    $obj = $resp | ConvertFrom-Json
    $order = $obj.result.orders | Where-Object { $_._id -eq $OrderId } | Select-Object -First 1
    $status = if ($order) { $order.orderStatus } else { 'unknown' }

    return @{ Message = $message; Status = $status }
}

# --- Reservation Widget Embed (X-Api-Key auth — NOT partner bearer) ---
#
# Confirmed from reservationWidget.route.ts: GET /embed uses authJwtOrApiKey, which also accepts
# a Bearer JWT, but the embed script's real caller (the restaurant's public website) only ever
# has the widget's own API key, so that's what this function uses.

# Get-GgReservationWidgetEmbed — requires $env:GG_WIDGET_EMBED_KEY (scripts/config/credentials.env).
function Get-GgReservationWidgetEmbed {
    Import-GgCredentials
    if (-not $env:GG_WIDGET_EMBED_KEY) {
        Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'GG_WIDGET_EMBED_KEY not set — see scripts/config/credentials.example.env'
    }
    $base = Resolve-GgBase
    return Invoke-GgHttpOrDie -Label 'reservation widget embed' -Method GET -Path "$base/v1/partner/reservation-widget/embed" `
        -Headers @{ 'X-Api-Key' = $env:GG_WIDGET_EMBED_KEY }
}

# --- Public Reservation (no auth — the signed `ref` token, format `xxx.yyy`, is the credential) ---
#
# Confirmed from src/routes/v1/genie/reservation.route.ts: genuinely no auth middleware, only rate
# limiters. Resolve-GgBase is used directly (not Get-GgSessionValue -Key base) so calling these
# never forces an unrelated partner+diner auth handshake.

function Get-GgPublicReservation {
    param([Parameter(Mandatory)][string]$Ref)
    $base = Resolve-GgBase
    return Invoke-GgHttpOrDie -Label 'public reservation get' -Method GET -Path "$base/v1/genie/reservation/$Ref"
}

# Get-GgPublicReservationReview <Ref> — the "Leave a review" redirect; Invoke-WebRequest follows
# redirects by default, so this returns whatever the final review-platform page serves.
function Get-GgPublicReservationReview {
    param([Parameter(Mandatory)][string]$Ref)
    $base = Resolve-GgBase
    return Invoke-GgHttpOrDie -Label 'public reservation review redirect' -Method GET -Path "$base/v1/genie/reservation/review/$Ref"
}

function Get-GgPublicReservationAvailability {
    param([Parameter(Mandatory)][string]$Ref, [Parameter(Mandatory)][string]$Date, [Parameter(Mandatory)][string]$PartySize)
    $base = Resolve-GgBase
    return Invoke-GgHttpOrDie -Label 'public reservation availability' -Method GET -Path "$base/v1/genie/reservation/$Ref/availability" `
        -Query @{ date = $Date; partySize = $PartySize }
}

# Update-GgPublicReservation <Ref> [-StartAt] [-PartySize] — body needs at least one of the two
# (the API's own Joi schema is `.min(1)`); this mirrors that instead of always sending both.
function Update-GgPublicReservation {
    param([Parameter(Mandatory)][string]$Ref, [string]$StartAt, [string]$PartySize)
    if (-not $StartAt -and -not $PartySize) {
        Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Update-GgPublicReservation: at least one of -StartAt/-PartySize required'
    }
    $base = Resolve-GgBase
    $fields = @{}
    if ($StartAt) { $fields['startAt'] = $StartAt }
    if ($PartySize) { $fields['partySize'] = [int]$PartySize }
    $body = $fields | ConvertTo-Json -Compress
    return Invoke-GgHttpOrDie -Label 'public reservation modify' -Method PATCH -Path "$base/v1/genie/reservation/$Ref" -JsonBody $body
}

# Cancel-GgPublicReservation <Ref> [-Reason] — cancel is its own endpoint, not folded into modify.
function Cancel-GgPublicReservation {
    param([Parameter(Mandatory)][string]$Ref, [string]$Reason = '')
    $base = Resolve-GgBase
    $body = New-GgJsonObj @{ reason = $Reason }
    return Invoke-GgHttpOrDie -Label 'public reservation cancel' -Method POST -Path "$base/v1/genie/reservation/$Ref/cancel" -JsonBody $body
}

# --- Front Desk Report (partner bearer; its own route file/controller, distinct from Insights.route.ts) ---

function Get-GgFrontDeskReport {
    param([Parameter(Mandatory)][string]$From, [Parameter(Mandatory)][string]$To, [string]$Scope = 'single', [string]$BranchId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $query = @{ from = $From; to = $To; scope = $Scope }
    if ($BranchId) { $query['branchId'] = $BranchId }
    return Invoke-GgHttpOrDie -Label 'front desk report' -Method GET -Path "$base/v1/partner/insights/front-desk" -Token $partnerToken -Query $query
}

# Export-GgFrontDeskReport <From> <To> [-Scope] [-BranchId] — returns the raw XLSX bytes as a
# string. Write it with a byte-preserving method (e.g. [System.IO.File]::WriteAllBytes via a
# fresh request, or accept that Invoke-WebRequest's string Content is already the same
# binary-unsafe capture Invoke-GgHttp uses everywhere else) — a pre-existing limitation of this
# library's "body is always a string" contract, not something new here.
function Export-GgFrontDeskReport {
    param([Parameter(Mandatory)][string]$From, [Parameter(Mandatory)][string]$To, [string]$Scope = 'single', [string]$BranchId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $query = @{ from = $From; to = $To; scope = $Scope; format = 'xlsx' }
    if ($BranchId) { $query['branchId'] = $BranchId }
    return Invoke-GgHttpOrDie -Label 'front desk report export' -Method GET -Path "$base/v1/partner/insights/front-desk/export" -Token $partnerToken -Query $query
}

# --- WhatsApp Agent Settings + Audience Segments (partner bearer) ---
#
# Confirmed mount path from src/routes/v1/partner/whatsapp/index.ts: agentSettings.route.ts is
# mounted at '/agent-settings' (kebab-case), not '/agentSettings'.

function Get-GgWhatsappAgentSettings {
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'whatsapp agent settings get' -Method GET -Path "$base/v1/partner/whatsapp/agent-settings" -Token $partnerToken
}

# Set-GgWhatsappAgentSettings <Field> <Value> — single-field patch. The body schema accepts any
# one (or more) of ~10 optional fields with `.min(1)`; this covers the common "change one
# setting" test case instead of exposing all ten as parameters.
function Set-GgWhatsappAgentSettings {
    param([Parameter(Mandatory)][string]$Field, [Parameter(Mandatory)][string]$Value)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $body = New-GgJsonObj @{ $Field = $Value }
    return Invoke-GgHttpOrDie -Label 'whatsapp agent settings update' -Method PATCH -Path "$base/v1/partner/whatsapp/agent-settings" -Token $partnerToken -JsonBody $body
}

function Get-GgWhatsappAudienceSegments {
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'whatsapp audience segments' -Method GET -Path "$base/v1/partner/whatsapp/campaigns/audience-segments" -Token $partnerToken
}

# --- Order History: Active Order By Table (partner bearer) ---

function Get-GgActiveOrderByTable {
    param([Parameter(Mandatory)][string]$TableId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'active order by table' -Method GET -Path "$base/v1/partner/order-history/active-by-table/$TableId" -Token $partnerToken
}

# --- Diner Extensions (diner bearer) ---

function Get-GgComboList {
    $base = Get-GgSessionValue -Key 'base'
    $dinerToken = Get-GgSessionValue -Key 'dinerToken'
    return Invoke-GgHttpOrDie -Label 'combo list' -Method GET -Path "$base/v1/genie/combo" -Token $dinerToken
}

function Get-GgDinerCombo {
    param([Parameter(Mandatory)][string]$ComboId)
    $base = Get-GgSessionValue -Key 'base'
    $dinerToken = Get-GgSessionValue -Key 'dinerToken'
    return Invoke-GgHttpOrDie -Label 'combo get' -Method GET -Path "$base/v1/genie/combo/$ComboId" -Token $dinerToken
}

function Get-GgDinerOrderDetail {
    param([Parameter(Mandatory)][string]$OrderId)
    $base = Get-GgSessionValue -Key 'base'
    $dinerToken = Get-GgSessionValue -Key 'dinerToken'
    return Invoke-GgHttpOrDie -Label 'diner order detail' -Method GET -Path "$base/v1/genie/order/$OrderId" -Token $dinerToken
}

# Confirm-GgLinkIdentity <Field> <Value> <Code> — Field is currently always "phone" (the API's
# own Joi schema only allows that one value), Value must be E.164, Code is the 6-digit OTP.
function Confirm-GgLinkIdentity {
    param([Parameter(Mandatory)][string]$Field, [Parameter(Mandatory)][string]$Value, [Parameter(Mandatory)][string]$Code)
    $base = Get-GgSessionValue -Key 'base'
    $dinerToken = Get-GgSessionValue -Key 'dinerToken'
    $body = New-GgJsonObj @{ field = $Field; value = $Value; code = $Code }
    return Invoke-GgHttpOrDie -Label 'diner link identity' -Method POST -Path "$base/v1/genie/profile/link-identity" -Token $dinerToken -JsonBody $body
}
