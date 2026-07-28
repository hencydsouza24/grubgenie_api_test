# Back-compat shim — see order.ps1. Usage: pwsh ./order_combo.ps1 [comboId] [-Qty 2]
# A function-level shim, not a script delegation — see order_item.ps1 for why.
param(
    [Parameter(Position = 0)][string]$ComboId,
    [int]$Qty = 1
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

if (-not $env:CART_ID) {
    Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'CART_ID not set — run: $env:CART_ID = & "create_cart.ps1"'
}
if (-not $ComboId) { $ComboId = $Script:GgComboSnack }

$orderId = New-GgOrder -CartId $env:CART_ID -LineKey 'comboId' -LineId $ComboId -Qty $Qty
$place = Submit-GgOrder -CartId $env:CART_ID -OrderId $orderId
Write-GgInfo "Place result: $($place.Message) (status: $($place.Status))"

Write-Output $orderId
