# E2E staff-assisted ordering flow (partner-authenticated): a waiter/captain starts a cart at a
# table, adds an item, updates the order with one more unit of it, then places it. Fully
# self-contained — auths itself via the shared session (see Auth.ps1).
# Usage: pwsh ./staff_order.ps1 <tableId> <itemId> [-Qty 2]
param(
    [Parameter(Mandatory, Position = 0)][string]$TableId,
    [Parameter(Mandatory, Position = 1)][string]$ItemId,
    [Parameter(Position = 2)][int]$Qty = 1
)
. "$PSScriptRoot/lib/Bootstrap.ps1"

Write-GgStep -Number '1' -Title 'Start table cart (staff)'
$cartId = New-GgStaffCart -TableId $TableId
Write-GgKv -Key 'Cart' -Value $cartId

Write-GgStep -Number '2' -Title "Add item to cart (itemId=$ItemId qty=$Qty)"
$orderId = New-GgStaffOrder -CartId $cartId -LineKey 'itemId' -LineId $ItemId -Qty $Qty
Write-GgKv -Key 'Order' -Value $orderId

Write-GgStep -Number '3' -Title 'Update order (add one more unit)'
$updateResp = Update-GgStaffOrder -OrderId $orderId -CartId $cartId -LineKey 'itemId' -LineId $ItemId -Qty 1
Write-GgInfo (Get-GgJsonMessage -Json $updateResp)

Write-GgStep -Number '4' -Title 'Place order'
$place = Submit-GgStaffOrder -OrderId $orderId -CartId $cartId
Write-GgInfo "$($place.Message) (status: $($place.Status))"

Write-GgStep -Number 'done' -Title 'Complete'
Write-GgInfo "Cart: $cartId | Order: $orderId"
