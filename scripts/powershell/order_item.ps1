# Back-compat shim — see order.ps1. Usage: pwsh ./order_item.ps1 <itemId> [-Qty 2]
# A function-level shim, not a script delegation: calling another .ps1 file via `&` or dot-source
# swallows that file's `exit` (PowerShell only propagates exit codes across a REAL subprocess
# boundary, e.g. `pwsh -File`), so this calls the same lib functions order.ps1 calls directly.
param(
    [Parameter(Mandatory, Position = 0)][string]$ItemId,
    [int]$Qty = 1
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

if (-not $env:CART_ID) {
    Exit-GgDie -ExitCode $Script:GgExitUsage -Message 'CART_ID not set — run: $env:CART_ID = & "create_cart.ps1"'
}

$orderId = New-GgOrder -CartId $env:CART_ID -LineKey 'itemId' -LineId $ItemId -Qty $Qty
$msg = Submit-GgOrder -CartId $env:CART_ID -OrderId $orderId
Write-GgInfo "Place result: $msg"

Write-Output $orderId
