# Full E2E dine-in + pay-in-person flow: auth -> cart -> order -> place -> (approve if needed)
# -> pay -> confirm. Fully self-contained — auths itself via the shared session (see auth.ps1).
# Usage: pwsh ./flow_dine_in_pay.ps1 [-ItemId <id>] [-Qty 2]
# Default item: 691bf10018f1d3c34db1db00 (Ulli Vada, 12 AED)
# Handles manual orderAcceptanceMode: auto-accepts a pending order before payment.
param(
    [string]$ItemId,
    [int]$Qty = 2
)
. "$PSScriptRoot/lib/Bootstrap.ps1"
if (-not $ItemId) { $ItemId = $Script:GgItemUlliVada }

Write-GgStep -Number '1' -Title 'Create cart'
$cartId = New-GgCart
Write-GgKv -Key 'Cart' -Value $cartId

Write-GgStep -Number '2' -Title "Create order (itemId=$ItemId qty=$Qty)"
$orderId = New-GgOrder -CartId $cartId -LineKey 'itemId' -LineId $ItemId -Qty $Qty
Write-GgKv -Key 'Order' -Value $orderId

Write-GgStep -Number '3' -Title 'Place order'
$place = Submit-GgOrder -CartId $cartId -OrderId $orderId
Write-GgInfo "$($place.Message) (status: $($place.Status))"

Write-GgStep -Number '4' -Title 'Accept order if pending approval'
if ($place.Status -eq 'pending_acceptance') {
    $acceptMsg = Set-GgOrderResponse -OrderId $orderId -Action 'accept'
    Write-GgInfo $acceptMsg
}
else {
    Write-GgInfo 'No approval needed, skipping.'
}

Write-GgStep -Number '5' -Title 'Pay in person'
$payMsg = Invoke-GgPayInPerson -CartId $cartId
Write-GgInfo $payMsg

Write-GgStep -Number '6' -Title 'Partner confirms payment'
$confirmMsg = Confirm-GgPayment -CartId $cartId
Write-GgInfo $confirmMsg

Write-GgStep -Number 'done' -Title 'Complete'
Write-GgInfo "Cart: $cartId | Order: $orderId"
