# GrubGenie domain verbs, expressed over Http.ps1 + Json.ps1. No raw Invoke-WebRequest here —
# that's the whole point: Http.ps1 knows nothing about carts, this file knows nothing about the
# HTTP engine. Dot-sourced by Bootstrap.ps1. Mirrors scripts/lib/api.sh function-for-function;
# the name mapping (bash -> PowerShell) is kept in one place here since later scripts (order.ps1,
# pos.ps1, ...) call these names directly:
#
#   gg_cart_create        -> New-GgCart
#   gg_order_create        -> New-GgOrder
#   gg_order_place          -> Submit-GgOrder
#   gg_order_respond        -> Set-GgOrderResponse
#   gg_pay_in_person        -> Invoke-GgPayInPerson
#   gg_payment_confirm      -> Confirm-GgPayment
#   gg_tables_list          -> Get-GgTables
#   gg_table_set_status     -> Set-GgTableStatus
#   gg_pos_menu             -> Get-GgPosMenu
#   gg_pos_items            -> Get-GgPosItems
#   gg_pos_sync             -> Start-GgPosSync
#   gg_pos_config_get       -> Get-GgPosConfig
#   gg_pos_config_setup     -> Set-GgPosConfig
#   gg_pos_config_disable   -> Remove-GgPosConfig

if (Get-Variable -Name _GgApiLoaded -Scope Script -ErrorAction SilentlyContinue) { return }
$Script:_GgApiLoaded = $true

function New-GgCart {
    $base = Get-GgSessionValue -Key 'base'
    $tableId = Get-GgSessionValue -Key 'tableId'
    $dinerToken = Get-GgSessionValue -Key 'dinerToken'

    $body = New-GgJsonObj @{ tableId = $tableId }
    $resp = Invoke-GgHttpOrDie -Label 'cart create' -Method POST -Path "$base/v1/genie/cart" -Token $dinerToken -JsonBody $body
    return Get-GgJsonField -Json $resp -Path '.result.cartId' -Label 'cartId'
}

# New-GgOrder <cartId> <lineKey> <lineId> [qty] — lineKey is "itemId" or "comboId". Prints the
# orderId. Replaces the item/combo script split: the two scripts differed only by this key, so
# it's now data, not a file.
function New-GgOrder {
    param(
        [Parameter(Mandatory)][string]$CartId,
        [Parameter(Mandatory)][ValidateSet('itemId', 'comboId')][string]$LineKey,
        [Parameter(Mandatory)][string]$LineId,
        [int]$Qty = 1
    )
    $base = Get-GgSessionValue -Key 'base'
    $dinerToken = Get-GgSessionValue -Key 'dinerToken'
    $dinerId = Get-GgSessionValue -Key 'dinerId'

    $line = @{ quantity = $Qty }
    $line[$LineKey] = $LineId
    $body = @{ items = @($line) } | ConvertTo-Json -Compress -Depth 5

    $resp = Invoke-GgHttpOrDie -Label 'order create' -Method POST -Path "$base/v1/genie/order" `
        -Token $dinerToken -JsonBody $body -Query @{ cartId = $CartId; dinerId = $dinerId }
    return Get-GgJsonField -Json $resp -Path '.result.currentActiveOrder' -Label 'orderId'
}

# Submit-GgOrder <cartId> <orderId> → the place-order response message.
function Submit-GgOrder {
    param([Parameter(Mandatory)][string]$CartId, [Parameter(Mandatory)][string]$OrderId)
    $base = Get-GgSessionValue -Key 'base'
    $dinerToken = Get-GgSessionValue -Key 'dinerToken'

    $resp = Invoke-GgHttpOrDie -Label 'place order' -Method PUT -Path "$base/v1/genie/order/place-order/$OrderId" `
        -Token $dinerToken -Query @{ cartId = $CartId }
    return Get-GgJsonMessage -Json $resp
}

# Set-GgOrderResponse <orderId> accept|reject → partner approves/rejects a manually-accepted
# order. Returns the response message.
function Set-GgOrderResponse {
    param([Parameter(Mandatory)][string]$OrderId, [Parameter(Mandatory)][ValidateSet('accept', 'reject')][string]$Action)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $body = New-GgJsonObj @{ action = $Action }
    $resp = Invoke-GgHttpOrDie -Label "order $Action" -Method PATCH -Path "$base/v1/partner/order-history/respond/$OrderId" `
        -Token $partnerToken -JsonBody $body
    return Get-GgJsonMessage -Json $resp
}

# Invoke-GgPayInPerson <cartId> → the response message.
function Invoke-GgPayInPerson {
    param([Parameter(Mandatory)][string]$CartId)
    $base = Get-GgSessionValue -Key 'base'
    $dinerToken = Get-GgSessionValue -Key 'dinerToken'
    $dinerId = Get-GgSessionValue -Key 'dinerId'

    $body = New-GgJsonObj @{ dinerId = $dinerId }
    $resp = Invoke-GgHttpOrDie -Label 'pay in person' -Method POST -Path "$base/v1/genie/cart/$CartId/payment/pay-in-person" `
        -Token $dinerToken -JsonBody $body
    return Get-GgJsonMessage -Json $resp
}

# Confirm-GgPayment <cartId> → partner confirms a cash payment. Returns the response message.
function Confirm-GgPayment {
    param([Parameter(Mandatory)][string]$CartId)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $body = @{ paymentStatus = 'done'; paymentMode = 'cash'; confirmed = $true } | ConvertTo-Json -Compress
    $resp = Invoke-GgHttpOrDie -Label 'confirm payment' -Method PUT -Path "$base/v1/partner/order-history/update-payment-status/$CartId" `
        -Token $partnerToken -JsonBody $body
    return Get-GgJsonMessage -Json $resp
}

function Get-GgTables {
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'table list' -Method GET -Path "$base/v1/partner/table" -Token $partnerToken
}

# Set-GgTableStatus <tableId> [status] → the response message.
function Set-GgTableStatus {
    param([Parameter(Mandatory)][string]$TableId, [string]$Status = 'available')
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $body = @{ status = $Status; confirmed = $true } | ConvertTo-Json -Compress
    $resp = Invoke-GgHttpOrDie -Label 'table status' -Method PUT -Path "$base/v1/partner/table/table-status/$TableId" `
        -Token $partnerToken -JsonBody $body
    return Get-GgJsonMessage -Json $resp
}

# --- Petpooja POS ---

function Get-GgPosMenu {
    param([string]$Provider = $Script:GgPosProvider)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'pos menu' -Method GET -Path "$base/v1/partner/pos/menu" -Token $partnerToken -Query @{ provider = $Provider }
}

function Get-GgPosItems {
    param([string]$Provider = $Script:GgPosProvider)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'pos items' -Method GET -Path "$base/v1/partner/pos/$Provider/items" -Token $partnerToken
}

# Start-GgPosSync [provider] — triggers the async menu import job. 202 (enqueued) and 409
# (already running) are both treated as success — a 409 means the sync this call wanted is
# already in flight, which is the caller's desired end state, not a failure.
function Start-GgPosSync {
    param([string]$Provider = $Script:GgPosProvider)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    $body = New-GgJsonObj @{ provider = $Provider }
    return Invoke-GgHttpOrDie -Label 'pos sync' -Method POST -Path "$base/v1/partner/pos/sync-menu" -Token $partnerToken -JsonBody $body -Expect '2xx,409'
}

function Get-GgPosConfig {
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'pos config get' -Method GET -Path "$base/v1/partner/branch/pos-config" -Token $partnerToken
}

# Set-GgPosConfig — requires $env:GG_PETPOOJA_APP_SECRET / $env:GG_PETPOOJA_ACCESS_TOKEN
# (scripts/config/credentials.env). appKey/restId are public fixtures from Constants.ps1.
function Set-GgPosConfig {
    Import-GgCredentials
    if (-not $env:GG_PETPOOJA_APP_SECRET -or -not $env:GG_PETPOOJA_ACCESS_TOKEN) {
        Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'GG_PETPOOJA_APP_SECRET/GG_PETPOOJA_ACCESS_TOKEN not set — see scripts/config/credentials.example.env'
    }
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'

    $body = @{
        provider    = $Script:GgPosProvider
        isEnabled   = $true
        credentials = @{
            appKey      = $Script:GgPosAppKey
            appSecret   = $env:GG_PETPOOJA_APP_SECRET
            accessToken = $env:GG_PETPOOJA_ACCESS_TOKEN
            restId      = $Script:GgPosRestId
        }
    } | ConvertTo-Json -Compress -Depth 5

    return Invoke-GgHttpOrDie -Label 'pos config setup' -Method PUT -Path "$base/v1/partner/branch/pos-config" -Token $partnerToken -JsonBody $body
}

function Remove-GgPosConfig {
    param([string]$Provider = $Script:GgPosProvider)
    $base = Get-GgSessionValue -Key 'base'
    $partnerToken = Get-GgSessionValue -Key 'partnerToken'
    return Invoke-GgHttpOrDie -Label 'pos config disable' -Method DELETE -Path "$base/v1/partner/branch/pos-config/$Provider" -Token $partnerToken
}
