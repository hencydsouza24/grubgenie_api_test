# Order a menu item or combo into an existing cart, then place it.
# Usage: pwsh ./order.ps1 item <itemId> [qty]
#        pwsh ./order.ps1 combo [comboId] [qty]
# Requires: $env:CART_ID (from create_cart.ps1) — run `$env:CART_ID = & "$SKILL/create_cart.ps1"`.
param(
    [Parameter(Mandatory, Position = 0)][ValidateSet('item', 'combo')][string]$Type,
    [Parameter(Position = 1)][string]$Id,
    [Parameter(Position = 2)][int]$Qty = 1
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

if (-not $env:CART_ID) {
    Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'CART_ID not set — run: $env:CART_ID = & "create_cart.ps1"'
}

if ($Type -eq 'item') {
    if (-not $Id) { Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'Usage: order.ps1 item <itemId> [qty]' }
    $lineKey = 'itemId'
    $lineId = $Id
}
else {
    $lineKey = 'comboId'
    $lineId = if ($Id) { $Id } else { $Script:GgComboSnack }
}

$orderId = New-GgOrder -CartId $env:CART_ID -LineKey $lineKey -LineId $lineId -Qty $Qty
$place = Submit-GgOrder -CartId $env:CART_ID -OrderId $orderId
Write-GgInfo "Place result: $($place.Message) (status: $($place.Status))"

Write-Output $orderId
